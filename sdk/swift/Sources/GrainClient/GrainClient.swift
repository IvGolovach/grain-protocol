import GrainClientFFI

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

    public func scanAcceptPrepare(qrString: String, trustPubB64: String) -> GrainScanAccept {
        let accepted = grainScanAcceptPrepare(
            request: FfiScanAcceptRequest(qrString: qrString, trustPubB64: trustPubB64)
        )
        return GrainScanAccept(accepted)
    }

    public func scanAccept(qrString: String, trustPubB64: String) -> GrainScanAccept {
        let accepted = store.scanAccept(
            request: FfiScanAcceptRequest(qrString: qrString, trustPubB64: trustPubB64)
        )
        return GrainScanAccept(accepted)
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
}

private extension GrainScanPreview {
    init(_ preview: FfiScanPreview) {
        self.init(
            status: GrainScanPreviewStatus(ffiStatus: preview.status),
            diag: preview.diag,
            coseB64: preview.coseB64
        )
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
