// swiftlint:disable all
import Foundation

// Depending on the consumer's build setup, the low-level FFI code
// might be in a separate module, or it might be compiled inline into
// this module. This is a bit of light hackery to work with both.
#if canImport(grain_client_coreFFI)
import grain_client_coreFFI
#endif

fileprivate extension RustBuffer {
    // Allocate a new buffer, copying the contents of a `UInt8` array.
    init(bytes: [UInt8]) {
        let rbuf = bytes.withUnsafeBufferPointer { ptr in
            RustBuffer.from(ptr)
        }
        self.init(capacity: rbuf.capacity, len: rbuf.len, data: rbuf.data)
    }

    static func empty() -> RustBuffer {
        RustBuffer(capacity: 0, len:0, data: nil)
    }

    static func from(_ ptr: UnsafeBufferPointer<UInt8>) -> RustBuffer {
        try! rustCall { ffi_grain_client_core_rustbuffer_from_bytes(ForeignBytes(bufferPointer: ptr), $0) }
    }

    // Frees the buffer in place.
    // The buffer must not be used after this is called.
    func deallocate() {
        try! rustCall { ffi_grain_client_core_rustbuffer_free(self, $0) }
    }
}

fileprivate extension ForeignBytes {
    init(bufferPointer: UnsafeBufferPointer<UInt8>) {
        self.init(len: Int32(bufferPointer.count), data: bufferPointer.baseAddress)
    }
}

// For every type used in the interface, we provide helper methods for conveniently
// lifting and lowering that type from C-compatible data, and for reading and writing
// values of that type in a buffer.

// Helper classes/extensions that don't change.
// Someday, this will be in a library of its own.

fileprivate extension Data {
    init(rustBuffer: RustBuffer) {
        self.init(
            bytesNoCopy: rustBuffer.data!,
            count: Int(rustBuffer.len),
            deallocator: .none
        )
    }
}

// Define reader functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.
//
// With external types, one swift source file needs to be able to call the read
// method on another source file's FfiConverter, but then what visibility
// should Reader have?
// - If Reader is fileprivate, then this means the read() must also
//   be fileprivate, which doesn't work with external types.
// - If Reader is internal/public, we'll get compile errors since both source
//   files will try define the same type.
//
// Instead, the read() method and these helper functions input a tuple of data

fileprivate func createReader(data: Data) -> (data: Data, offset: Data.Index) {
    (data: data, offset: 0)
}

// Reads an integer at the current offset, in big-endian order, and advances
// the offset on success. Throws if reading the integer would move the
// offset past the end of the buffer.
fileprivate func readInt<T: FixedWidthInteger>(_ reader: inout (data: Data, offset: Data.Index)) throws -> T {
    let range = reader.offset..<reader.offset + MemoryLayout<T>.size
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    if T.self == UInt8.self {
        let value = reader.data[reader.offset]
        reader.offset += 1
        return value as! T
    }
    var value: T = 0
    let _ = withUnsafeMutableBytes(of: &value, { reader.data.copyBytes(to: $0, from: range)})
    reader.offset = range.upperBound
    return value.bigEndian
}

// Reads an arbitrary number of bytes, to be used to read
// raw bytes, this is useful when lifting strings
fileprivate func readBytes(_ reader: inout (data: Data, offset: Data.Index), count: Int) throws -> Array<UInt8> {
    let range = reader.offset..<(reader.offset+count)
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    var value = [UInt8](repeating: 0, count: count)
    value.withUnsafeMutableBufferPointer({ buffer in
        reader.data.copyBytes(to: buffer, from: range)
    })
    reader.offset = range.upperBound
    return value
}

// Reads a float at the current offset.
fileprivate func readFloat(_ reader: inout (data: Data, offset: Data.Index)) throws -> Float {
    return Float(bitPattern: try readInt(&reader))
}

// Reads a float at the current offset.
fileprivate func readDouble(_ reader: inout (data: Data, offset: Data.Index)) throws -> Double {
    return Double(bitPattern: try readInt(&reader))
}

// Indicates if the offset has reached the end of the buffer.
fileprivate func hasRemaining(_ reader: (data: Data, offset: Data.Index)) -> Bool {
    return reader.offset < reader.data.count
}

// Define writer functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.  See the above discussion on Readers for details.

fileprivate func createWriter() -> [UInt8] {
    return []
}

fileprivate func writeBytes<S>(_ writer: inout [UInt8], _ byteArr: S) where S: Sequence, S.Element == UInt8 {
    writer.append(contentsOf: byteArr)
}

// Writes an integer in big-endian order.
//
// Warning: make sure what you are trying to write
// is in the correct type!
fileprivate func writeInt<T: FixedWidthInteger>(_ writer: inout [UInt8], _ value: T) {
    var value = value.bigEndian
    withUnsafeBytes(of: &value) { writer.append(contentsOf: $0) }
}

fileprivate func writeFloat(_ writer: inout [UInt8], _ value: Float) {
    writeInt(&writer, value.bitPattern)
}

fileprivate func writeDouble(_ writer: inout [UInt8], _ value: Double) {
    writeInt(&writer, value.bitPattern)
}

// Protocol for types that transfer other types across the FFI. This is
// analogous to the Rust trait of the same name.
fileprivate protocol FfiConverter {
    associatedtype FfiType
    associatedtype SwiftType

    static func lift(_ value: FfiType) throws -> SwiftType
    static func lower(_ value: SwiftType) -> FfiType
    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType
    static func write(_ value: SwiftType, into buf: inout [UInt8])
}

// Types conforming to `Primitive` pass themselves directly over the FFI.
fileprivate protocol FfiConverterPrimitive: FfiConverter where FfiType == SwiftType { }

extension FfiConverterPrimitive {
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lift(_ value: FfiType) throws -> SwiftType {
        return value
    }

#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lower(_ value: SwiftType) -> FfiType {
        return value
    }
}

// Types conforming to `FfiConverterRustBuffer` lift and lower into a `RustBuffer`.
// Used for complex types where it's hard to write a custom lift/lower.
fileprivate protocol FfiConverterRustBuffer: FfiConverter where FfiType == RustBuffer {}

extension FfiConverterRustBuffer {
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lift(_ buf: RustBuffer) throws -> SwiftType {
        var reader = createReader(data: Data(rustBuffer: buf))
        let value = try read(from: &reader)
        if hasRemaining(reader) {
            throw UniffiInternalError.incompleteData
        }
        buf.deallocate()
        return value
    }

#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lower(_ value: SwiftType) -> RustBuffer {
          var writer = createWriter()
          write(value, into: &writer)
          return RustBuffer(bytes: writer)
    }
}
// An error type for FFI errors. These errors occur at the UniFFI level, not
// the library level.
fileprivate enum UniffiInternalError: LocalizedError {
    case bufferOverflow
    case incompleteData
    case unexpectedOptionalTag
    case unexpectedEnumCase
    case unexpectedNullPointer
    case unexpectedRustCallStatusCode
    case unexpectedRustCallError
    case unexpectedStaleHandle
    case rustPanic(_ message: String)

    public var errorDescription: String? {
        switch self {
        case .bufferOverflow: return "Reading the requested value would read past the end of the buffer"
        case .incompleteData: return "The buffer still has data after lifting its containing value"
        case .unexpectedOptionalTag: return "Unexpected optional tag; should be 0 or 1"
        case .unexpectedEnumCase: return "Raw enum value doesn't match any cases"
        case .unexpectedNullPointer: return "Raw pointer value was null"
        case .unexpectedRustCallStatusCode: return "Unexpected RustCallStatus code"
        case .unexpectedRustCallError: return "CALL_ERROR but no errorClass specified"
        case .unexpectedStaleHandle: return "The object in the handle map has been dropped already"
        case let .rustPanic(message): return message
        }
    }
}

fileprivate extension NSLock {
    func withLock<T>(f: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try f()
    }
}

fileprivate let CALL_SUCCESS: Int8 = 0
fileprivate let CALL_ERROR: Int8 = 1
fileprivate let CALL_UNEXPECTED_ERROR: Int8 = 2
fileprivate let CALL_CANCELLED: Int8 = 3

fileprivate extension RustCallStatus {
    init() {
        self.init(
            code: CALL_SUCCESS,
            errorBuf: RustBuffer.init(
                capacity: 0,
                len: 0,
                data: nil
            )
        )
    }
}

private func rustCall<T>(_ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    let neverThrow: ((RustBuffer) throws -> Never)? = nil
    return try makeRustCall(callback, errorHandler: neverThrow)
}

private func rustCallWithError<T, E: Swift.Error>(
    _ errorHandler: @escaping (RustBuffer) throws -> E,
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    try makeRustCall(callback, errorHandler: errorHandler)
}

private func makeRustCall<T, E: Swift.Error>(
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T,
    errorHandler: ((RustBuffer) throws -> E)?
) throws -> T {
    uniffiEnsureGrainClientCoreInitialized()
    var callStatus = RustCallStatus.init()
    let returnedVal = callback(&callStatus)
    try uniffiCheckCallStatus(callStatus: callStatus, errorHandler: errorHandler)
    return returnedVal
}

private func uniffiCheckCallStatus<E: Swift.Error>(
    callStatus: RustCallStatus,
    errorHandler: ((RustBuffer) throws -> E)?
) throws {
    switch callStatus.code {
        case CALL_SUCCESS:
            return

        case CALL_ERROR:
            if let errorHandler = errorHandler {
                throw try errorHandler(callStatus.errorBuf)
            } else {
                callStatus.errorBuf.deallocate()
                throw UniffiInternalError.unexpectedRustCallError
            }

        case CALL_UNEXPECTED_ERROR:
            // When the rust code sees a panic, it tries to construct a RustBuffer
            // with the message.  But if that code panics, then it just sends back
            // an empty buffer.
            if callStatus.errorBuf.len > 0 {
                throw UniffiInternalError.rustPanic(try FfiConverterString.lift(callStatus.errorBuf))
            } else {
                callStatus.errorBuf.deallocate()
                throw UniffiInternalError.rustPanic("Rust panic")
            }

        case CALL_CANCELLED:
            fatalError("Cancellation not supported yet")

        default:
            throw UniffiInternalError.unexpectedRustCallStatusCode
    }
}

private func uniffiTraitInterfaceCall<T>(
    callStatus: UnsafeMutablePointer<RustCallStatus>,
    makeCall: () throws -> T,
    writeReturn: (T) -> ()
) {
    do {
        try writeReturn(makeCall())
    } catch let error {
        callStatus.pointee.code = CALL_UNEXPECTED_ERROR
        callStatus.pointee.errorBuf = FfiConverterString.lower(String(describing: error))
    }
}

private func uniffiTraitInterfaceCallWithError<T, E>(
    callStatus: UnsafeMutablePointer<RustCallStatus>,
    makeCall: () throws -> T,
    writeReturn: (T) -> (),
    lowerError: (E) -> RustBuffer
) {
    do {
        try writeReturn(makeCall())
    } catch let error as E {
        callStatus.pointee.code = CALL_ERROR
        callStatus.pointee.errorBuf = lowerError(error)
    } catch {
        callStatus.pointee.code = CALL_UNEXPECTED_ERROR
        callStatus.pointee.errorBuf = FfiConverterString.lower(String(describing: error))
    }
}
// Initial value and increment amount for handles.
// These ensure that SWIFT handles always have the lowest bit set
fileprivate let UNIFFI_HANDLEMAP_INITIAL: UInt64 = 1
fileprivate let UNIFFI_HANDLEMAP_DELTA: UInt64 = 2

fileprivate final class UniffiHandleMap<T>: @unchecked Sendable {
    // All mutation happens with this lock held, which is why we implement @unchecked Sendable.
    private let lock = NSLock()
    private var map: [UInt64: T] = [:]
    private var currentHandle: UInt64 = UNIFFI_HANDLEMAP_INITIAL

    func insert(obj: T) -> UInt64 {
        lock.withLock {
            return doInsert(obj)
        }
    }

    // Low-level insert function, this assumes `lock` is held.
    private func doInsert(_ obj: T) -> UInt64 {
        let handle = currentHandle
        currentHandle += UNIFFI_HANDLEMAP_DELTA
        map[handle] = obj
        return handle
    }

     func get(handle: UInt64) throws -> T {
        try lock.withLock {
            guard let obj = map[handle] else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return obj
        }
    }

     func clone(handle: UInt64) throws -> UInt64 {
        try lock.withLock {
            guard let obj = map[handle] else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return doInsert(obj)
        }
    }

    @discardableResult
    func remove(handle: UInt64) throws -> T {
        try lock.withLock {
            guard let obj = map.removeValue(forKey: handle) else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return obj
        }
    }

    var count: Int {
        get {
            map.count
        }
    }
}


// Public interface members begin here.


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterUInt64: FfiConverterPrimitive {
    typealias FfiType = UInt64
    typealias SwiftType = UInt64

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> UInt64 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterString: FfiConverter {
    typealias SwiftType = String
    typealias FfiType = RustBuffer

    public static func lift(_ value: RustBuffer) throws -> String {
        defer {
            value.deallocate()
        }
        if value.data == nil {
            return String()
        }
        let bytes = UnsafeBufferPointer<UInt8>(start: value.data!, count: Int(value.len))
        return String(bytes: bytes, encoding: String.Encoding.utf8)!
    }

    public static func lower(_ value: String) -> RustBuffer {
        return value.utf8CString.withUnsafeBufferPointer { ptr in
            // The swift string gives us int8_t, we want uint8_t.
            ptr.withMemoryRebound(to: UInt8.self) { ptr in
                // The swift string gives us a trailing null byte, we don't want it.
                let buf = UnsafeBufferPointer(rebasing: ptr.prefix(upTo: ptr.count - 1))
                return RustBuffer.from(buf)
            }
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> String {
        let len: Int32 = try readInt(&buf)
        return String(bytes: try readBytes(&buf, count: Int(len)), encoding: String.Encoding.utf8)!
    }

    public static func write(_ value: String, into buf: inout [UInt8]) {
        let len = Int32(value.utf8.count)
        writeInt(&buf, len)
        writeBytes(&buf, value.utf8)
    }
}




public protocol GrainClientMemoryStoreProtocol: AnyObject, Sendable {

    func acceptPairingEnvelope(request: FfiPairingEnvelopeRequest)  -> FfiPairingResult

    func addDeviceKey(label: String)  -> FfiDeviceResult

    func clientLifecycle()  -> FfiClientLifecycle

    func createPairingEnvelope()  -> FfiPairingResult

    func createRootIdentity(label: String)  -> FfiIdentityResult

    func exportIdentityBundle()  -> FfiIdentityResult

    func exportSyncBundle()  -> FfiSyncResult

    func importIdentityBundle(bundleB64: String)  -> FfiIdentityResult

    func importSyncBundle(request: FfiSyncBundleRequest)  -> FfiSyncResult

    func listAcceptedScans()  -> [FfiAcceptedScan]

    func revokeDeviceKey(ak: String)  -> FfiDeviceResult

    func scanAccept(request: FfiScanAcceptRequest)  -> FfiScanAccept

    func setActiveDevice(ak: String)  -> FfiDeviceResult

}
open class GrainClientMemoryStore: GrainClientMemoryStoreProtocol, @unchecked Sendable {
    fileprivate let handle: UInt64

    /// Used to instantiate a [FFIObject] without an actual handle, for fakes in tests, mostly.
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public struct NoHandle {
        public init() {}
    }

    // TODO: We'd like this to be `private` but for Swifty reasons,
    // we can't implement `FfiConverter` without making this `required` and we can't
    // make it `required` without making it `public`.
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    required public init(unsafeFromHandle handle: UInt64) {
        self.handle = handle
    }

    // This constructor can be used to instantiate a fake object.
    // - Parameter noHandle: Placeholder value so we can have a constructor separate from the default empty one that may be implemented for classes extending [FFIObject].
    //
    // - Warning:
    //     Any object instantiated with this constructor cannot be passed to an actual Rust-backed object. Since there isn't a backing handle the FFI lower functions will crash.
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public init(noHandle: NoHandle) {
        self.handle = 0
    }

#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public func uniffiCloneHandle() -> UInt64 {
        return try! rustCall { uniffi_grain_client_core_fn_clone_grainclientmemorystore(self.handle, $0) }
    }
public convenience init() {
    let handle =
        try! rustCall() {
    uniffi_grain_client_core_fn_constructor_grainclientmemorystore_new($0
    )
}
    self.init(unsafeFromHandle: handle)
}

    deinit {
        if handle == 0 {
            // Mock objects have handle=0 don't try to free them
            return
        }

        try! rustCall { uniffi_grain_client_core_fn_free_grainclientmemorystore(handle, $0) }
    }




open func acceptPairingEnvelope(request: FfiPairingEnvelopeRequest) -> FfiPairingResult  {
    return try!  FfiConverterTypeFfiPairingResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_accept_pairing_envelope(
            self.uniffiCloneHandle(),
        FfiConverterTypeFfiPairingEnvelopeRequest_lower(request),$0
    )
})
}

open func addDeviceKey(label: String) -> FfiDeviceResult  {
    return try!  FfiConverterTypeFfiDeviceResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_add_device_key(
            self.uniffiCloneHandle(),
        FfiConverterString.lower(label),$0
    )
})
}

open func clientLifecycle() -> FfiClientLifecycle  {
    return try!  FfiConverterTypeFfiClientLifecycle_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_client_lifecycle(
            self.uniffiCloneHandle(),$0
    )
})
}

open func createPairingEnvelope() -> FfiPairingResult  {
    return try!  FfiConverterTypeFfiPairingResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_create_pairing_envelope(
            self.uniffiCloneHandle(),$0
    )
})
}

open func createRootIdentity(label: String) -> FfiIdentityResult  {
    return try!  FfiConverterTypeFfiIdentityResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_create_root_identity(
            self.uniffiCloneHandle(),
        FfiConverterString.lower(label),$0
    )
})
}

open func exportIdentityBundle() -> FfiIdentityResult  {
    return try!  FfiConverterTypeFfiIdentityResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_export_identity_bundle(
            self.uniffiCloneHandle(),$0
    )
})
}

open func exportSyncBundle() -> FfiSyncResult  {
    return try!  FfiConverterTypeFfiSyncResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_export_sync_bundle(
            self.uniffiCloneHandle(),$0
    )
})
}

open func importIdentityBundle(bundleB64: String) -> FfiIdentityResult  {
    return try!  FfiConverterTypeFfiIdentityResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_import_identity_bundle(
            self.uniffiCloneHandle(),
        FfiConverterString.lower(bundleB64),$0
    )
})
}

open func importSyncBundle(request: FfiSyncBundleRequest) -> FfiSyncResult  {
    return try!  FfiConverterTypeFfiSyncResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_import_sync_bundle(
            self.uniffiCloneHandle(),
        FfiConverterTypeFfiSyncBundleRequest_lower(request),$0
    )
})
}

open func listAcceptedScans() -> [FfiAcceptedScan]  {
    return try!  FfiConverterSequenceTypeFfiAcceptedScan.lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_list_accepted_scans(
            self.uniffiCloneHandle(),$0
    )
})
}

open func revokeDeviceKey(ak: String) -> FfiDeviceResult  {
    return try!  FfiConverterTypeFfiDeviceResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_revoke_device_key(
            self.uniffiCloneHandle(),
        FfiConverterString.lower(ak),$0
    )
})
}

open func scanAccept(request: FfiScanAcceptRequest) -> FfiScanAccept  {
    return try!  FfiConverterTypeFfiScanAccept_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_scan_accept(
            self.uniffiCloneHandle(),
        FfiConverterTypeFfiScanAcceptRequest_lower(request),$0
    )
})
}

open func setActiveDevice(ak: String) -> FfiDeviceResult  {
    return try!  FfiConverterTypeFfiDeviceResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_method_grainclientmemorystore_set_active_device(
            self.uniffiCloneHandle(),
        FfiConverterString.lower(ak),$0
    )
})
}



}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeGrainClientMemoryStore: FfiConverter {
    typealias FfiType = UInt64
    typealias SwiftType = GrainClientMemoryStore

    public static func lift(_ handle: UInt64) throws -> GrainClientMemoryStore {
        return GrainClientMemoryStore(unsafeFromHandle: handle)
    }

    public static func lower(_ value: GrainClientMemoryStore) -> UInt64 {
        return value.uniffiCloneHandle()
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> GrainClientMemoryStore {
        let handle: UInt64 = try readInt(&buf)
        return try lift(handle)
    }

    public static func write(_ value: GrainClientMemoryStore, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeGrainClientMemoryStore_lift(_ handle: UInt64) throws -> GrainClientMemoryStore {
    return try FfiConverterTypeGrainClientMemoryStore.lift(handle)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeGrainClientMemoryStore_lower(_ value: GrainClientMemoryStore) -> UInt64 {
    return FfiConverterTypeGrainClientMemoryStore.lower(value)
}




public struct FfiAcceptedScan: Equatable, Hashable {
    public var scanId: String
    public var coseB64: String
    public var trustPubB64: String

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(scanId: String, coseB64: String, trustPubB64: String) {
        self.scanId = scanId
        self.coseB64 = coseB64
        self.trustPubB64 = trustPubB64
    }




}

#if compiler(>=6)
extension FfiAcceptedScan: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiAcceptedScan: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiAcceptedScan {
        return
            try FfiAcceptedScan(
                scanId: FfiConverterString.read(from: &buf),
                coseB64: FfiConverterString.read(from: &buf),
                trustPubB64: FfiConverterString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiAcceptedScan, into buf: inout [UInt8]) {
        FfiConverterString.write(value.scanId, into: &buf)
        FfiConverterString.write(value.coseB64, into: &buf)
        FfiConverterString.write(value.trustPubB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiAcceptedScan_lift(_ buf: RustBuffer) throws -> FfiAcceptedScan {
    return try FfiConverterTypeFfiAcceptedScan.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiAcceptedScan_lower(_ value: FfiAcceptedScan) -> RustBuffer {
    return FfiConverterTypeFfiAcceptedScan.lower(value)
}


public struct FfiClientLifecycle: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var rootKid: String?
    public var activeAk: String?
    public var deviceCount: UInt64
    public var revokedCount: UInt64
    public var acceptedRecordCount: UInt64
    public var lifecycleEventCount: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], rootKid: String?, activeAk: String?, deviceCount: UInt64, revokedCount: UInt64, acceptedRecordCount: UInt64, lifecycleEventCount: UInt64) {
        self.status = status
        self.diag = diag
        self.rootKid = rootKid
        self.activeAk = activeAk
        self.deviceCount = deviceCount
        self.revokedCount = revokedCount
        self.acceptedRecordCount = acceptedRecordCount
        self.lifecycleEventCount = lifecycleEventCount
    }




}

#if compiler(>=6)
extension FfiClientLifecycle: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiClientLifecycle: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiClientLifecycle {
        return
            try FfiClientLifecycle(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                rootKid: FfiConverterOptionString.read(from: &buf),
                activeAk: FfiConverterOptionString.read(from: &buf),
                deviceCount: FfiConverterUInt64.read(from: &buf),
                revokedCount: FfiConverterUInt64.read(from: &buf),
                acceptedRecordCount: FfiConverterUInt64.read(from: &buf),
                lifecycleEventCount: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: FfiClientLifecycle, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.rootKid, into: &buf)
        FfiConverterOptionString.write(value.activeAk, into: &buf)
        FfiConverterUInt64.write(value.deviceCount, into: &buf)
        FfiConverterUInt64.write(value.revokedCount, into: &buf)
        FfiConverterUInt64.write(value.acceptedRecordCount, into: &buf)
        FfiConverterUInt64.write(value.lifecycleEventCount, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiClientLifecycle_lift(_ buf: RustBuffer) throws -> FfiClientLifecycle {
    return try FfiConverterTypeFfiClientLifecycle.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiClientLifecycle_lower(_ value: FfiClientLifecycle) -> RustBuffer {
    return FfiConverterTypeFfiClientLifecycle.lower(value)
}


public struct FfiDeviceResult: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var deviceAk: String?
    public var activeAk: String?
    public var rootKid: String?
    public var deviceCount: UInt64
    public var revokedCount: UInt64
    public var lifecycleEventCount: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], deviceAk: String?, activeAk: String?, rootKid: String?, deviceCount: UInt64, revokedCount: UInt64, lifecycleEventCount: UInt64) {
        self.status = status
        self.diag = diag
        self.deviceAk = deviceAk
        self.activeAk = activeAk
        self.rootKid = rootKid
        self.deviceCount = deviceCount
        self.revokedCount = revokedCount
        self.lifecycleEventCount = lifecycleEventCount
    }




}

#if compiler(>=6)
extension FfiDeviceResult: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiDeviceResult: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiDeviceResult {
        return
            try FfiDeviceResult(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                deviceAk: FfiConverterOptionString.read(from: &buf),
                activeAk: FfiConverterOptionString.read(from: &buf),
                rootKid: FfiConverterOptionString.read(from: &buf),
                deviceCount: FfiConverterUInt64.read(from: &buf),
                revokedCount: FfiConverterUInt64.read(from: &buf),
                lifecycleEventCount: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: FfiDeviceResult, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.deviceAk, into: &buf)
        FfiConverterOptionString.write(value.activeAk, into: &buf)
        FfiConverterOptionString.write(value.rootKid, into: &buf)
        FfiConverterUInt64.write(value.deviceCount, into: &buf)
        FfiConverterUInt64.write(value.revokedCount, into: &buf)
        FfiConverterUInt64.write(value.lifecycleEventCount, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiDeviceResult_lift(_ buf: RustBuffer) throws -> FfiDeviceResult {
    return try FfiConverterTypeFfiDeviceResult.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiDeviceResult_lower(_ value: FfiDeviceResult) -> RustBuffer {
    return FfiConverterTypeFfiDeviceResult.lower(value)
}


public struct FfiIdentityResult: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var rootKid: String?
    public var activeAk: String?
    public var bundleB64: String?
    public var deviceCount: UInt64
    public var revokedCount: UInt64
    public var lifecycleEventCount: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], rootKid: String?, activeAk: String?, bundleB64: String?, deviceCount: UInt64, revokedCount: UInt64, lifecycleEventCount: UInt64) {
        self.status = status
        self.diag = diag
        self.rootKid = rootKid
        self.activeAk = activeAk
        self.bundleB64 = bundleB64
        self.deviceCount = deviceCount
        self.revokedCount = revokedCount
        self.lifecycleEventCount = lifecycleEventCount
    }




}

#if compiler(>=6)
extension FfiIdentityResult: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiIdentityResult: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiIdentityResult {
        return
            try FfiIdentityResult(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                rootKid: FfiConverterOptionString.read(from: &buf),
                activeAk: FfiConverterOptionString.read(from: &buf),
                bundleB64: FfiConverterOptionString.read(from: &buf),
                deviceCount: FfiConverterUInt64.read(from: &buf),
                revokedCount: FfiConverterUInt64.read(from: &buf),
                lifecycleEventCount: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: FfiIdentityResult, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.rootKid, into: &buf)
        FfiConverterOptionString.write(value.activeAk, into: &buf)
        FfiConverterOptionString.write(value.bundleB64, into: &buf)
        FfiConverterUInt64.write(value.deviceCount, into: &buf)
        FfiConverterUInt64.write(value.revokedCount, into: &buf)
        FfiConverterUInt64.write(value.lifecycleEventCount, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiIdentityResult_lift(_ buf: RustBuffer) throws -> FfiIdentityResult {
    return try FfiConverterTypeFfiIdentityResult.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiIdentityResult_lower(_ value: FfiIdentityResult) -> RustBuffer {
    return FfiConverterTypeFfiIdentityResult.lower(value)
}


public struct FfiPairingEnvelopeRequest: Equatable, Hashable {
    public var envelopeB64: String

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(envelopeB64: String) {
        self.envelopeB64 = envelopeB64
    }




}

#if compiler(>=6)
extension FfiPairingEnvelopeRequest: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiPairingEnvelopeRequest: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiPairingEnvelopeRequest {
        return
            try FfiPairingEnvelopeRequest(
                envelopeB64: FfiConverterString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiPairingEnvelopeRequest, into buf: inout [UInt8]) {
        FfiConverterString.write(value.envelopeB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiPairingEnvelopeRequest_lift(_ buf: RustBuffer) throws -> FfiPairingEnvelopeRequest {
    return try FfiConverterTypeFfiPairingEnvelopeRequest.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiPairingEnvelopeRequest_lower(_ value: FfiPairingEnvelopeRequest) -> RustBuffer {
    return FfiConverterTypeFfiPairingEnvelopeRequest.lower(value)
}


public struct FfiPairingResult: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var pairingId: String?
    public var envelopeB64: String?
    public var rootKid: String?
    public var deviceCount: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], pairingId: String?, envelopeB64: String?, rootKid: String?, deviceCount: UInt64) {
        self.status = status
        self.diag = diag
        self.pairingId = pairingId
        self.envelopeB64 = envelopeB64
        self.rootKid = rootKid
        self.deviceCount = deviceCount
    }




}

#if compiler(>=6)
extension FfiPairingResult: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiPairingResult: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiPairingResult {
        return
            try FfiPairingResult(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                pairingId: FfiConverterOptionString.read(from: &buf),
                envelopeB64: FfiConverterOptionString.read(from: &buf),
                rootKid: FfiConverterOptionString.read(from: &buf),
                deviceCount: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: FfiPairingResult, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.pairingId, into: &buf)
        FfiConverterOptionString.write(value.envelopeB64, into: &buf)
        FfiConverterOptionString.write(value.rootKid, into: &buf)
        FfiConverterUInt64.write(value.deviceCount, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiPairingResult_lift(_ buf: RustBuffer) throws -> FfiPairingResult {
    return try FfiConverterTypeFfiPairingResult.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiPairingResult_lower(_ value: FfiPairingResult) -> RustBuffer {
    return FfiConverterTypeFfiPairingResult.lower(value)
}


public struct FfiScanAccept: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var scanId: String?
    public var coseB64: String?
    public var trustPubB64: String?

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], scanId: String?, coseB64: String?, trustPubB64: String?) {
        self.status = status
        self.diag = diag
        self.scanId = scanId
        self.coseB64 = coseB64
        self.trustPubB64 = trustPubB64
    }




}

#if compiler(>=6)
extension FfiScanAccept: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiScanAccept: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiScanAccept {
        return
            try FfiScanAccept(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                scanId: FfiConverterOptionString.read(from: &buf),
                coseB64: FfiConverterOptionString.read(from: &buf),
                trustPubB64: FfiConverterOptionString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiScanAccept, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.scanId, into: &buf)
        FfiConverterOptionString.write(value.coseB64, into: &buf)
        FfiConverterOptionString.write(value.trustPubB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanAccept_lift(_ buf: RustBuffer) throws -> FfiScanAccept {
    return try FfiConverterTypeFfiScanAccept.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanAccept_lower(_ value: FfiScanAccept) -> RustBuffer {
    return FfiConverterTypeFfiScanAccept.lower(value)
}


public struct FfiScanAcceptRequest: Equatable, Hashable {
    public var qrString: String
    public var trustPubB64: String

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(qrString: String, trustPubB64: String) {
        self.qrString = qrString
        self.trustPubB64 = trustPubB64
    }




}

#if compiler(>=6)
extension FfiScanAcceptRequest: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiScanAcceptRequest: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiScanAcceptRequest {
        return
            try FfiScanAcceptRequest(
                qrString: FfiConverterString.read(from: &buf),
                trustPubB64: FfiConverterString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiScanAcceptRequest, into buf: inout [UInt8]) {
        FfiConverterString.write(value.qrString, into: &buf)
        FfiConverterString.write(value.trustPubB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanAcceptRequest_lift(_ buf: RustBuffer) throws -> FfiScanAcceptRequest {
    return try FfiConverterTypeFfiScanAcceptRequest.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanAcceptRequest_lower(_ value: FfiScanAcceptRequest) -> RustBuffer {
    return FfiConverterTypeFfiScanAcceptRequest.lower(value)
}


public struct FfiScanPreview: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var coseB64: String?

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], coseB64: String?) {
        self.status = status
        self.diag = diag
        self.coseB64 = coseB64
    }




}

#if compiler(>=6)
extension FfiScanPreview: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiScanPreview: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiScanPreview {
        return
            try FfiScanPreview(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                coseB64: FfiConverterOptionString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiScanPreview, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.coseB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanPreview_lift(_ buf: RustBuffer) throws -> FfiScanPreview {
    return try FfiConverterTypeFfiScanPreview.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanPreview_lower(_ value: FfiScanPreview) -> RustBuffer {
    return FfiConverterTypeFfiScanPreview.lower(value)
}


public struct FfiScanPreviewRequest: Equatable, Hashable {
    public var qrString: String
    public var trustPubB64: String?

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(qrString: String, trustPubB64: String?) {
        self.qrString = qrString
        self.trustPubB64 = trustPubB64
    }




}

#if compiler(>=6)
extension FfiScanPreviewRequest: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiScanPreviewRequest: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiScanPreviewRequest {
        return
            try FfiScanPreviewRequest(
                qrString: FfiConverterString.read(from: &buf),
                trustPubB64: FfiConverterOptionString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiScanPreviewRequest, into buf: inout [UInt8]) {
        FfiConverterString.write(value.qrString, into: &buf)
        FfiConverterOptionString.write(value.trustPubB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanPreviewRequest_lift(_ buf: RustBuffer) throws -> FfiScanPreviewRequest {
    return try FfiConverterTypeFfiScanPreviewRequest.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiScanPreviewRequest_lower(_ value: FfiScanPreviewRequest) -> RustBuffer {
    return FfiConverterTypeFfiScanPreviewRequest.lower(value)
}


public struct FfiSyncBundleRequest: Equatable, Hashable {
    public var bundleB64: String

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(bundleB64: String) {
        self.bundleB64 = bundleB64
    }




}

#if compiler(>=6)
extension FfiSyncBundleRequest: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiSyncBundleRequest: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiSyncBundleRequest {
        return
            try FfiSyncBundleRequest(
                bundleB64: FfiConverterString.read(from: &buf)
        )
    }

    public static func write(_ value: FfiSyncBundleRequest, into buf: inout [UInt8]) {
        FfiConverterString.write(value.bundleB64, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiSyncBundleRequest_lift(_ buf: RustBuffer) throws -> FfiSyncBundleRequest {
    return try FfiConverterTypeFfiSyncBundleRequest.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiSyncBundleRequest_lower(_ value: FfiSyncBundleRequest) -> RustBuffer {
    return FfiConverterTypeFfiSyncBundleRequest.lower(value)
}


public struct FfiSyncResult: Equatable, Hashable {
    public var status: String
    public var diag: [String]
    public var bundleB64: String?
    public var acceptedRecordCount: UInt64
    public var deviceCount: UInt64
    public var lifecycleEventCount: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(status: String, diag: [String], bundleB64: String?, acceptedRecordCount: UInt64, deviceCount: UInt64, lifecycleEventCount: UInt64) {
        self.status = status
        self.diag = diag
        self.bundleB64 = bundleB64
        self.acceptedRecordCount = acceptedRecordCount
        self.deviceCount = deviceCount
        self.lifecycleEventCount = lifecycleEventCount
    }




}

#if compiler(>=6)
extension FfiSyncResult: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeFfiSyncResult: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> FfiSyncResult {
        return
            try FfiSyncResult(
                status: FfiConverterString.read(from: &buf),
                diag: FfiConverterSequenceString.read(from: &buf),
                bundleB64: FfiConverterOptionString.read(from: &buf),
                acceptedRecordCount: FfiConverterUInt64.read(from: &buf),
                deviceCount: FfiConverterUInt64.read(from: &buf),
                lifecycleEventCount: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: FfiSyncResult, into buf: inout [UInt8]) {
        FfiConverterString.write(value.status, into: &buf)
        FfiConverterSequenceString.write(value.diag, into: &buf)
        FfiConverterOptionString.write(value.bundleB64, into: &buf)
        FfiConverterUInt64.write(value.acceptedRecordCount, into: &buf)
        FfiConverterUInt64.write(value.deviceCount, into: &buf)
        FfiConverterUInt64.write(value.lifecycleEventCount, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiSyncResult_lift(_ buf: RustBuffer) throws -> FfiSyncResult {
    return try FfiConverterTypeFfiSyncResult.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeFfiSyncResult_lower(_ value: FfiSyncResult) -> RustBuffer {
    return FfiConverterTypeFfiSyncResult.lower(value)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterOptionString: FfiConverterRustBuffer {
    typealias SwiftType = String?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterString.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterString.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterSequenceString: FfiConverterRustBuffer {
    typealias SwiftType = [String]

    public static func write(_ value: [String], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterString.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [String] {
        let len: Int32 = try readInt(&buf)
        var seq = [String]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterString.read(from: &buf))
        }
        return seq
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterSequenceTypeFfiAcceptedScan: FfiConverterRustBuffer {
    typealias SwiftType = [FfiAcceptedScan]

    public static func write(_ value: [FfiAcceptedScan], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterTypeFfiAcceptedScan.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [FfiAcceptedScan] {
        let len: Int32 = try readInt(&buf)
        var seq = [FfiAcceptedScan]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterTypeFfiAcceptedScan.read(from: &buf))
        }
        return seq
    }
}
public func grainPairingPreviewEnvelope(request: FfiPairingEnvelopeRequest) -> FfiPairingResult  {
    return try!  FfiConverterTypeFfiPairingResult_lift(try! rustCall() {
    uniffi_grain_client_core_fn_func_grain_pairing_preview_envelope(
        FfiConverterTypeFfiPairingEnvelopeRequest_lower(request),$0
    )
})
}
public func grainScanAcceptPrepare(request: FfiScanAcceptRequest) -> FfiScanAccept  {
    return try!  FfiConverterTypeFfiScanAccept_lift(try! rustCall() {
    uniffi_grain_client_core_fn_func_grain_scan_accept_prepare(
        FfiConverterTypeFfiScanAcceptRequest_lower(request),$0
    )
})
}
public func grainScanPreview(request: FfiScanPreviewRequest) -> FfiScanPreview  {
    return try!  FfiConverterTypeFfiScanPreview_lift(try! rustCall() {
    uniffi_grain_client_core_fn_func_grain_scan_preview(
        FfiConverterTypeFfiScanPreviewRequest_lower(request),$0
    )
})
}

private enum InitializationResult {
    case ok
    case contractVersionMismatch
    case apiChecksumMismatch
}
// Use a global variable to perform the versioning checks. Swift ensures that
// the code inside is only computed once.
private let initializationResult: InitializationResult = {
    // Get the bindings contract version from our ComponentInterface
    let bindings_contract_version = 30
    // Get the scaffolding contract version by calling the into the dylib
    let scaffolding_contract_version = ffi_grain_client_core_uniffi_contract_version()
    if bindings_contract_version != scaffolding_contract_version {
        return InitializationResult.contractVersionMismatch
    }
    if (uniffi_grain_client_core_checksum_func_grain_pairing_preview_envelope() != 30814) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_func_grain_scan_accept_prepare() != 15446) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_func_grain_scan_preview() != 16442) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_accept_pairing_envelope() != 36871) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_add_device_key() != 21084) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_client_lifecycle() != 17197) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_create_pairing_envelope() != 50408) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_create_root_identity() != 47300) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_export_identity_bundle() != 55887) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_export_sync_bundle() != 32552) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_import_identity_bundle() != 8443) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_import_sync_bundle() != 51237) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_list_accepted_scans() != 25163) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_revoke_device_key() != 6663) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_scan_accept() != 58218) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_method_grainclientmemorystore_set_active_device() != 10852) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_grain_client_core_checksum_constructor_grainclientmemorystore_new() != 12349) {
        return InitializationResult.apiChecksumMismatch
    }

    return InitializationResult.ok
}()

// Make the ensure init function public so that other modules which have external type references to
// our types can call it.
public func uniffiEnsureGrainClientCoreInitialized() {
    switch initializationResult {
    case .ok:
        break
    case .contractVersionMismatch:
        fatalError("UniFFI contract version mismatch: try cleaning and rebuilding your project")
    case .apiChecksumMismatch:
        fatalError("UniFFI API checksum mismatch: try cleaning and rebuilding your project")
    }
}

// swiftlint:enable all
