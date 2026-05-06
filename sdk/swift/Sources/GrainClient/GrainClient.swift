import Foundation
import GrainClientFFI

private let sdkErrTrustAnchorRequired = "SDK_ERR_TRUST_ANCHOR_REQUIRED"
private let sdkErrTrustAnchorNotFound = "SDK_ERR_TRUST_ANCHOR_NOT_FOUND"
private let sdkErrTrustAnchorBundleInvalid = "SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID"

public enum GrainTrustAnchorBundleError: Error, Equatable, Sendable {
    case invalid(String)
}

public enum GrainScanPreviewStatus: Equatable, Sendable {
    case verified
    case untrusted
    case rejected
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .verified:
            return "Verified"
        case .untrusted:
            return "Untrusted"
        case .rejected:
            return "Rejected"
        case let .unknown(value):
            return value
        }
    }

    init(ffiStatus: String) {
        switch ffiStatus {
        case "Verified":
            self = .verified
        case "Untrusted":
            self = .untrusted
        case "Rejected":
            self = .rejected
        default:
            self = .unknown(ffiStatus)
        }
    }
}

public enum GrainScanAcceptStatus: Equatable, Sendable {
    case accepted
    case alreadyAccepted
    case rejected
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .accepted:
            return "Accepted"
        case .alreadyAccepted:
            return "AlreadyAccepted"
        case .rejected:
            return "Rejected"
        case let .unknown(value):
            return value
        }
    }

    init(ffiStatus: String) {
        switch ffiStatus {
        case "Accepted":
            self = .accepted
        case "AlreadyAccepted":
            self = .alreadyAccepted
        case "Rejected":
            self = .rejected
        default:
            self = .unknown(ffiStatus)
        }
    }
}

public struct GrainScanPreview: Equatable, Sendable {
    public let status: GrainScanPreviewStatus
    public let diag: [String]
    public let coseB64: String?
}

public struct GrainScanAccept: Equatable, Sendable {
    public let status: GrainScanAcceptStatus
    public let diag: [String]
    public let scanID: String?
    public let coseB64: String?
    public let trustPubB64: String?
}

public struct GrainAcceptedScan: Equatable, Sendable {
    public let scanID: String
    public let coseB64: String
    public let trustPubB64: String
}

public struct GrainIdentityResult: Equatable, Sendable {
    public let status: String
    public let diag: [String]
    public let rootKID: String?
    public let activeAK: String?
    public let bundleB64: String?
    public let deviceCount: UInt64
    public let revokedCount: UInt64
    public let lifecycleEventCount: UInt64
}

public struct GrainDeviceResult: Equatable, Sendable {
    public let status: String
    public let diag: [String]
    public let deviceAK: String?
    public let activeAK: String?
    public let rootKID: String?
    public let deviceCount: UInt64
    public let revokedCount: UInt64
    public let lifecycleEventCount: UInt64
}

public struct GrainClientLifecycle: Equatable, Sendable {
    public let status: String
    public let diag: [String]
    public let rootKID: String?
    public let activeAK: String?
    public let deviceCount: UInt64
    public let revokedCount: UInt64
    public let acceptedRecordCount: UInt64
    public let lifecycleEventCount: UInt64
}

public struct GrainPairingResult: Equatable, Sendable {
    public let status: String
    public let diag: [String]
    public let pairingID: String?
    public let envelopeB64: String?
    public let rootKID: String?
    public let deviceCount: UInt64
}

public struct GrainSyncResult: Equatable, Sendable {
    public let status: String
    public let diag: [String]
    public let bundleB64: String?
    public let acceptedRecordCount: UInt64
    public let deviceCount: UInt64
    public let lifecycleEventCount: UInt64
}

public struct GrainStoreSnapshotResult: Equatable, Sendable {
    public let status: String
    public let diag: [String]
    public let snapshotB64: String?
    public let acceptedRecordCount: UInt64
    public let deviceCount: UInt64
    public let lifecycleEventCount: UInt64
}

public enum GrainCustodyMaterial: String, Equatable, Sendable {
    case storeSnapshot
    case identityBundle
    case pairingEnvelope
    case syncBundle
    case trustMaterial
}

public enum GrainCustodyBinding: String, Equatable, Sendable {
    case portableTransfer
    case deviceKeychain
    case deviceKeystore
    case secureEnclave
    case externalSecureModule
    case appManaged
}

public struct GrainCustodyDescriptor: Equatable, Sendable {
    public let material: GrainCustodyMaterial
    public let binding: GrainCustodyBinding
    public let exportable: Bool
    public let deviceBound: Bool

    public init(
        material: GrainCustodyMaterial,
        binding: GrainCustodyBinding,
        exportable: Bool,
        deviceBound: Bool
    ) {
        self.material = material
        self.binding = binding
        self.exportable = exportable
        self.deviceBound = deviceBound
    }
}

public enum GrainCustodyPolicies {
    public static func portableIdentityBundle() -> GrainCustodyDescriptor {
        portable(.identityBundle)
    }

    public static func portablePairingEnvelope() -> GrainCustodyDescriptor {
        portable(.pairingEnvelope)
    }

    public static func portableSyncBundle() -> GrainCustodyDescriptor {
        portable(.syncBundle)
    }

    public static func keychainSnapshot() -> GrainCustodyDescriptor {
        GrainCustodyDescriptor(
            material: .storeSnapshot,
            binding: .deviceKeychain,
            exportable: false,
            deviceBound: true
        )
    }

    public static func secureEnclaveSnapshot() -> GrainCustodyDescriptor {
        GrainCustodyDescriptor(
            material: .storeSnapshot,
            binding: .secureEnclave,
            exportable: false,
            deviceBound: true
        )
    }

    private static func portable(_ material: GrainCustodyMaterial) -> GrainCustodyDescriptor {
        GrainCustodyDescriptor(
            material: material,
            binding: .portableTransfer,
            exportable: true,
            deviceBound: false
        )
    }
}

public protocol GrainTrustProvider: Sendable {
    func trustPubB64(anchorID: String) -> String?
}

public struct GrainStaticTrustProvider: GrainTrustProvider, Sendable {
    private let anchors: [String: String]

    public init(anchors: [String: String]) {
        self.anchors = anchors
    }

    public init(anchorID: String, trustPubB64: String) {
        self.anchors = [anchorID: trustPubB64]
    }

    public init(bundleJSON: String) throws {
        self.anchors = try parseTrustAnchorBundleJSON(bundleJSON)
    }

    public func trustPubB64(anchorID: String) -> String? {
        anchors[anchorID]
    }
}

private func parseTrustAnchorBundleJSON(_ bundleJSON: String) throws -> [String: String] {
    func invalid() throws -> Never {
        throw GrainTrustAnchorBundleError.invalid(sdkErrTrustAnchorBundleInvalid)
    }

    let raw: Any
    do {
        raw = try JSONSerialization.jsonObject(with: Data(bundleJSON.utf8))
    } catch {
        try invalid()
    }
    guard let bundle = raw as? [String: Any],
          Set(bundle.keys) == Set(["bundle_v", "anchors"]),
          let bundleVersion = bundle["bundle_v"] as? Int,
          bundleVersion == 1,
          let rawAnchors = bundle["anchors"] as? [Any],
          !rawAnchors.isEmpty
    else {
        try invalid()
    }

    var anchors: [String: String] = [:]
    for rawAnchor in rawAnchors {
        guard let anchor = rawAnchor as? [String: Any],
              Set(anchor.keys) == Set(["id", "trust_pub_b64"]),
              let anchorID = anchor["id"] as? String,
              !anchorID.isEmpty,
              anchorID.trimmingCharacters(in: .whitespacesAndNewlines) == anchorID,
              anchors[anchorID] == nil,
              let trustPubB64 = anchor["trust_pub_b64"] as? String,
              let trustBytes = Data(base64Encoded: trustPubB64),
              !trustBytes.isEmpty
        else {
            try invalid()
        }
        anchors[anchorID] = trustPubB64
    }

    return anchors
}

public final class GrainClient {
    private let store: GrainClientMemoryStore

    public init() {
        self.store = GrainClientMemoryStore()
    }

    public func scanPreview(qrString: String, trustPubB64: String? = nil) -> GrainScanPreview {
        let preview = grainScanPreview(
            request: FfiScanPreviewRequest(qrString: qrString, trustPubB64: trustPubB64)
        )
        return GrainScanPreview(preview)
    }

    public func scanPreview(
        qrString: String,
        trustAnchorID: String,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanPreview {
        switch resolveTrustPubB64(anchorID: trustAnchorID, trustProvider: trustProvider) {
        case let .resolved(trustPubB64):
            return scanPreview(qrString: qrString, trustPubB64: trustPubB64)
        case let .rejected(diag):
            return GrainScanPreview.rejected(diag)
        }
    }

    public func scanAcceptPrepare(qrString: String, trustPubB64: String) -> GrainScanAccept {
        let accepted = grainScanAcceptPrepare(
            request: FfiScanAcceptRequest(qrString: qrString, trustPubB64: trustPubB64)
        )
        return GrainScanAccept(accepted)
    }

    public func scanAcceptPrepare(
        qrString: String,
        trustAnchorID: String,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanAccept {
        switch resolveTrustPubB64(anchorID: trustAnchorID, trustProvider: trustProvider) {
        case let .resolved(trustPubB64):
            return scanAcceptPrepare(qrString: qrString, trustPubB64: trustPubB64)
        case let .rejected(diag):
            return GrainScanAccept.rejected(diag)
        }
    }

    public func scanAccept(qrString: String, trustPubB64: String) -> GrainScanAccept {
        let accepted = store.scanAccept(
            request: FfiScanAcceptRequest(qrString: qrString, trustPubB64: trustPubB64)
        )
        return GrainScanAccept(accepted)
    }

    public func scanAccept(
        qrString: String,
        trustAnchorID: String,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanAccept {
        switch resolveTrustPubB64(anchorID: trustAnchorID, trustProvider: trustProvider) {
        case let .resolved(trustPubB64):
            return scanAccept(qrString: qrString, trustPubB64: trustPubB64)
        case let .rejected(diag):
            return GrainScanAccept.rejected(diag)
        }
    }

    public func listAcceptedScans() -> [GrainAcceptedScan] {
        store.listAcceptedScans().map(GrainAcceptedScan.init)
    }

    public func createRootIdentity(label: String = "root") -> GrainIdentityResult {
        GrainIdentityResult(store.createRootIdentity(label: label))
    }

    public func exportIdentityBundle() -> GrainIdentityResult {
        GrainIdentityResult(store.exportIdentityBundle())
    }

    public func importIdentityBundle(bundleB64: String) -> GrainIdentityResult {
        GrainIdentityResult(store.importIdentityBundle(bundleB64: bundleB64))
    }

    public func addDeviceKey(label: String = "device") -> GrainDeviceResult {
        GrainDeviceResult(store.addDeviceKey(label: label))
    }

    public func revokeDeviceKey(ak: String) -> GrainDeviceResult {
        GrainDeviceResult(store.revokeDeviceKey(ak: ak))
    }

    public func setActiveDevice(ak: String) -> GrainDeviceResult {
        GrainDeviceResult(store.setActiveDevice(ak: ak))
    }

    public func clientLifecycle() -> GrainClientLifecycle {
        GrainClientLifecycle(store.clientLifecycle())
    }

    public func createPairingEnvelope() -> GrainPairingResult {
        GrainPairingResult(store.createPairingEnvelope())
    }

    public func previewPairingEnvelope(envelopeB64: String) -> GrainPairingResult {
        GrainPairingResult(
            grainPairingPreviewEnvelope(
                request: FfiPairingEnvelopeRequest(envelopeB64: envelopeB64)
            )
        )
    }

    public func acceptPairingEnvelope(envelopeB64: String) -> GrainPairingResult {
        GrainPairingResult(
            store.acceptPairingEnvelope(
                request: FfiPairingEnvelopeRequest(envelopeB64: envelopeB64)
            )
        )
    }

    public func exportSyncBundle() -> GrainSyncResult {
        GrainSyncResult(store.exportSyncBundle())
    }

    public func importSyncBundle(bundleB64: String) -> GrainSyncResult {
        GrainSyncResult(
            store.importSyncBundle(
                request: FfiSyncBundleRequest(bundleB64: bundleB64)
            )
        )
    }

    public func exportStoreSnapshot() -> GrainStoreSnapshotResult {
        GrainStoreSnapshotResult(store.exportStoreSnapshot())
    }

    public func restoreStoreSnapshot(snapshotB64: String) -> GrainStoreSnapshotResult {
        GrainStoreSnapshotResult(store.restoreStoreSnapshot(snapshotB64: snapshotB64))
    }
}

private enum GrainTrustResolution {
    case resolved(String)
    case rejected(String)
}

private func resolveTrustPubB64(
    anchorID: String,
    trustProvider: any GrainTrustProvider
) -> GrainTrustResolution {
    if anchorID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .rejected(sdkErrTrustAnchorRequired)
    }
    guard let trustPubB64 = trustProvider.trustPubB64(anchorID: anchorID) else {
        return .rejected(sdkErrTrustAnchorNotFound)
    }
    return .resolved(trustPubB64)
}

private func redactedOptional(_ value: String?) -> String {
    value == nil ? "nil" : "[REDACTED]"
}

extension GrainScanPreview: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainScanPreview(status: \(status.rawValue), diag: \(diag), coseB64: \(redactedOptional(coseB64)))"
    }

    public var debugDescription: String { description }
}

extension GrainScanAccept: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainScanAccept(status: \(status.rawValue), diag: \(diag), scanID: \(String(describing: scanID)), " +
            "coseB64: \(redactedOptional(coseB64)), trustPubB64: \(redactedOptional(trustPubB64)))"
    }

    public var debugDescription: String { description }
}

extension GrainAcceptedScan: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainAcceptedScan(scanID: \(scanID), coseB64: [REDACTED], trustPubB64: [REDACTED])"
    }

    public var debugDescription: String { description }
}

extension GrainIdentityResult: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainIdentityResult(status: \(status), diag: \(diag), rootKID: \(String(describing: rootKID)), " +
            "activeAK: \(String(describing: activeAK)), bundleB64: \(redactedOptional(bundleB64)), " +
            "deviceCount: \(deviceCount), revokedCount: \(revokedCount), " +
            "lifecycleEventCount: \(lifecycleEventCount))"
    }

    public var debugDescription: String { description }
}

extension GrainPairingResult: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainPairingResult(status: \(status), diag: \(diag), pairingID: \(String(describing: pairingID)), " +
            "envelopeB64: \(redactedOptional(envelopeB64)), rootKID: \(String(describing: rootKID)), " +
            "deviceCount: \(deviceCount))"
    }

    public var debugDescription: String { description }
}

extension GrainSyncResult: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainSyncResult(status: \(status), diag: \(diag), bundleB64: \(redactedOptional(bundleB64)), " +
            "acceptedRecordCount: \(acceptedRecordCount), deviceCount: \(deviceCount), " +
            "lifecycleEventCount: \(lifecycleEventCount))"
    }

    public var debugDescription: String { description }
}

extension GrainStoreSnapshotResult: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "GrainStoreSnapshotResult(status: \(status), diag: \(diag), snapshotB64: \(redactedOptional(snapshotB64)), " +
            "acceptedRecordCount: \(acceptedRecordCount), deviceCount: \(deviceCount), " +
            "lifecycleEventCount: \(lifecycleEventCount))"
    }

    public var debugDescription: String { description }
}

private extension GrainScanPreview {
    init(_ preview: FfiScanPreview) {
        self.init(
            status: GrainScanPreviewStatus(ffiStatus: preview.status),
            diag: preview.diag,
            coseB64: preview.coseB64
        )
    }

    static func rejected(_ diag: String) -> Self {
        self.init(status: .rejected, diag: [diag], coseB64: nil)
    }
}

private extension GrainScanAccept {
    init(_ accepted: FfiScanAccept) {
        self.init(
            status: GrainScanAcceptStatus(ffiStatus: accepted.status),
            diag: accepted.diag,
            scanID: accepted.scanId,
            coseB64: accepted.coseB64,
            trustPubB64: accepted.trustPubB64
        )
    }

    static func rejected(_ diag: String) -> Self {
        self.init(status: .rejected, diag: [diag], scanID: nil, coseB64: nil, trustPubB64: nil)
    }
}

private extension GrainAcceptedScan {
    init(_ accepted: FfiAcceptedScan) {
        self.init(
            scanID: accepted.scanId,
            coseB64: accepted.coseB64,
            trustPubB64: accepted.trustPubB64
        )
    }
}

private extension GrainIdentityResult {
    init(_ result: FfiIdentityResult) {
        self.init(
            status: result.status,
            diag: result.diag,
            rootKID: result.rootKid,
            activeAK: result.activeAk,
            bundleB64: result.bundleB64,
            deviceCount: result.deviceCount,
            revokedCount: result.revokedCount,
            lifecycleEventCount: result.lifecycleEventCount
        )
    }
}

private extension GrainDeviceResult {
    init(_ result: FfiDeviceResult) {
        self.init(
            status: result.status,
            diag: result.diag,
            deviceAK: result.deviceAk,
            activeAK: result.activeAk,
            rootKID: result.rootKid,
            deviceCount: result.deviceCount,
            revokedCount: result.revokedCount,
            lifecycleEventCount: result.lifecycleEventCount
        )
    }
}

private extension GrainClientLifecycle {
    init(_ result: FfiClientLifecycle) {
        self.init(
            status: result.status,
            diag: result.diag,
            rootKID: result.rootKid,
            activeAK: result.activeAk,
            deviceCount: result.deviceCount,
            revokedCount: result.revokedCount,
            acceptedRecordCount: result.acceptedRecordCount,
            lifecycleEventCount: result.lifecycleEventCount
        )
    }
}

private extension GrainPairingResult {
    init(_ result: FfiPairingResult) {
        self.init(
            status: result.status,
            diag: result.diag,
            pairingID: result.pairingId,
            envelopeB64: result.envelopeB64,
            rootKID: result.rootKid,
            deviceCount: result.deviceCount
        )
    }
}

private extension GrainSyncResult {
    init(_ result: FfiSyncResult) {
        self.init(
            status: result.status,
            diag: result.diag,
            bundleB64: result.bundleB64,
            acceptedRecordCount: result.acceptedRecordCount,
            deviceCount: result.deviceCount,
            lifecycleEventCount: result.lifecycleEventCount
        )
    }
}

private extension GrainStoreSnapshotResult {
    init(_ result: FfiStoreSnapshotResult) {
        self.init(
            status: result.status,
            diag: result.diag,
            snapshotB64: result.snapshotB64,
            acceptedRecordCount: result.acceptedRecordCount,
            deviceCount: result.deviceCount,
            lifecycleEventCount: result.lifecycleEventCount
        )
    }
}
