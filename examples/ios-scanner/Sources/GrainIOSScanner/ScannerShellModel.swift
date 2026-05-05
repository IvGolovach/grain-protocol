import Combine
import GrainClient

public let scannerAcceptRequiresVerifiedPreviewDiag = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW"
public let scannerAcceptRequiresTrustDiag = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_TRUST"

public protocol ScannerWorkflowClient {
    func scanPreview(qrString: String, trustPubB64: String?) -> GrainScanPreview
    func scanAccept(qrString: String, trustPubB64: String) -> GrainScanAccept
    func listAcceptedScans() -> [GrainAcceptedScan]
    func createRootIdentity(label: String) -> GrainIdentityResult
    func addDeviceKey(label: String) -> GrainDeviceResult
    func clientLifecycle() -> GrainClientLifecycle
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
    public var lifecycleStatus: String?
    public var deviceCount: UInt64
    public var lifecycleEventCount: UInt64

    public init(
        qrString: String = "",
        trustPubB64: String = "",
        previewStatus: GrainScanPreviewStatus? = nil,
        acceptStatus: GrainScanAcceptStatus? = nil,
        diagnostics: [String] = [],
        canAccept: Bool = false,
        acceptedCount: Int = 0,
        acceptedScanID: String? = nil,
        lifecycleStatus: String? = nil,
        deviceCount: UInt64 = 0,
        lifecycleEventCount: UInt64 = 0
    ) {
        self.qrString = qrString
        self.trustPubB64 = trustPubB64
        self.previewStatus = previewStatus
        self.acceptStatus = acceptStatus
        self.diagnostics = diagnostics
        self.canAccept = canAccept
        self.acceptedCount = acceptedCount
        self.acceptedScanID = acceptedScanID
        self.lifecycleStatus = lifecycleStatus
        self.deviceCount = deviceCount
        self.lifecycleEventCount = lifecycleEventCount
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

    public func prepareLocalIdentity(rootLabel: String = "phone", deviceLabel: String = "scanner") {
        let lifecycle = client.clientLifecycle()
        if lifecycle.status == "Ready" {
            state.diagnostics = lifecycle.diag
            applyLifecycle(lifecycle)
            return
        }
        if lifecycle.status == "Uninitialized" {
            let root = client.createRootIdentity(label: rootLabel)
            if !root.diag.isEmpty {
                state.diagnostics = root.diag
                refreshLifecycle()
                return
            }
        }

        let device = client.addDeviceKey(label: deviceLabel)
        state.diagnostics = device.diag
        refreshLifecycle()
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

    private func refreshLifecycle() {
        let lifecycle = client.clientLifecycle()
        applyLifecycle(lifecycle)
    }

    private func applyLifecycle(_ lifecycle: GrainClientLifecycle) {
        state.lifecycleStatus = lifecycle.status
        state.deviceCount = lifecycle.deviceCount
        state.lifecycleEventCount = lifecycle.lifecycleEventCount
    }

    private func resetDecisionState() {
        state.previewStatus = nil
        state.acceptStatus = nil
        state.acceptedScanID = nil
        state.diagnostics = []
        state.canAccept = false
    }
}
