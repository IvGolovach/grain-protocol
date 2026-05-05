import Combine
import GrainClient

public let scannerAcceptRequiresVerifiedPreviewDiag = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW"
public let scannerAcceptRequiresTrustDiag = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_TRUST"

public protocol ScannerWorkflowClient {
    func scanPreview(qrString: String, trustPubB64: String?) -> GrainScanPreview
    func scanAccept(qrString: String, trustPubB64: String) -> GrainScanAccept
    func listAcceptedScans() -> [GrainAcceptedScan]
}

extension GrainClient: ScannerWorkflowClient {}

public struct ScannerShellState: Equatable, Sendable {
    public var qrString: String
    public var trustPubB64: String
    public var previewStatus: GrainScanPreviewStatus?
    public var acceptStatus: GrainScanAcceptStatus?
    public var diagnostics: [String]
    public var canAccept: Bool
    public var acceptedCount: Int
    public var acceptedScanID: String?

    public init(
        qrString: String = "",
        trustPubB64: String = "",
        previewStatus: GrainScanPreviewStatus? = nil,
        acceptStatus: GrainScanAcceptStatus? = nil,
        diagnostics: [String] = [],
        canAccept: Bool = false,
        acceptedCount: Int = 0,
        acceptedScanID: String? = nil
    ) {
        self.qrString = qrString
        self.trustPubB64 = trustPubB64
        self.previewStatus = previewStatus
        self.acceptStatus = acceptStatus
        self.diagnostics = diagnostics
        self.canAccept = canAccept
        self.acceptedCount = acceptedCount
        self.acceptedScanID = acceptedScanID
    }
}

@MainActor
public final class ScannerShellModel: ObservableObject {
    @Published public private(set) var state: ScannerShellState

    private let client: ScannerWorkflowClient

    public init(client: ScannerWorkflowClient = GrainClient()) {
        self.client = client
        self.state = ScannerShellState()
    }

    public func updateQrString(_ value: String) {
        state.qrString = value
        resetDecisionState()
    }

    public func updateTrustPubB64(_ value: String) {
        state.trustPubB64 = value
        resetDecisionState()
    }

    public func receiveCameraPayload(_ payload: CameraScanPayload) {
        state.qrString = payload.qrString
        resetDecisionState()
    }

    public func preview() {
        let preview = client.scanPreview(
            qrString: state.qrString,
            trustPubB64: normalizedTrustInput()
        )

        state.previewStatus = preview.status
        state.acceptStatus = nil
        state.acceptedScanID = nil
        state.diagnostics = preview.diag
        state.canAccept = preview.status == .verified
        state.acceptedCount = client.listAcceptedScans().count
    }

    public func accept() {
        guard state.previewStatus == .verified, state.canAccept else {
            state.diagnostics = [scannerAcceptRequiresVerifiedPreviewDiag]
            state.acceptStatus = nil
            state.acceptedScanID = nil
            state.canAccept = false
            return
        }

        guard let trustPubB64 = normalizedTrustInput() else {
            state.diagnostics = [scannerAcceptRequiresTrustDiag]
            state.acceptStatus = nil
            state.acceptedScanID = nil
            state.canAccept = false
            return
        }

        let accepted = client.scanAccept(qrString: state.qrString, trustPubB64: trustPubB64)
        state.acceptStatus = accepted.status
        state.acceptedScanID = accepted.scanID
        state.diagnostics = accepted.diag
        state.acceptedCount = client.listAcceptedScans().count
        state.canAccept = state.previewStatus == .verified
    }

    private func normalizedTrustInput() -> String? {
        let trimmed = state.trustPubB64.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resetDecisionState() {
        state.previewStatus = nil
        state.acceptStatus = nil
        state.acceptedScanID = nil
        state.diagnostics = []
        state.canAccept = false
    }
}
