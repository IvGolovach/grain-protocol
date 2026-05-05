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
