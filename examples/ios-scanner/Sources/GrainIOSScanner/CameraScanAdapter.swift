import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

public enum CameraScanSource: String, Equatable, Sendable {
    case camera
    case injected
}

public struct CameraScanPayload: Equatable, Sendable {
    public let qrString: String
    public let source: CameraScanSource

    public init(qrString: String, source: CameraScanSource) {
        self.qrString = qrString
        self.source = source
    }
}

@MainActor
public protocol CameraScanAdapter {
    func nextScanPayload() async throws -> CameraScanPayload?
}

public final class InjectedCameraScanAdapter: CameraScanAdapter {
    private var qrStrings: [String]

    public init(qrStrings: [String]) {
        self.qrStrings = qrStrings
    }

    public func nextScanPayload() async throws -> CameraScanPayload? {
        guard !qrStrings.isEmpty else {
            return nil
        }
        return CameraScanPayload(qrString: qrStrings.removeFirst(), source: .injected)
    }
}

#if canImport(AVFoundation)
public struct AVFoundationQRCodeMetadataAdapter {
    public init() {}

    public func payload(from object: AVMetadataObject) -> CameraScanPayload? {
        guard
            let readable = object as? AVMetadataMachineReadableCodeObject,
            readable.type == .qr,
            let qrString = readable.stringValue,
            !qrString.isEmpty
        else {
            return nil
        }

        return CameraScanPayload(qrString: qrString, source: .camera)
    }
}
#endif
