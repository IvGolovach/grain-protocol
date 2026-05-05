import Combine
import GrainClient
import GrainClientIOSAdapters

public let scannerAcceptRequiresVerifiedPreviewDiag = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW"
public let scannerSnapshotPersistenceDiag = "SDK_ERR_EXAMPLE_SNAPSHOT_PERSISTENCE"

public protocol ScannerWorkflowClient: GrainSnapshotClient {
    func scanPreview(
        qrString: String,
        trustAnchorID: String,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanPreview
    func scanAccept(
        qrString: String,
        trustAnchorID: String,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanAccept
    func listAcceptedScans() -> [GrainAcceptedScan]
    func createRootIdentity(label: String) -> GrainIdentityResult
    func addDeviceKey(label: String) -> GrainDeviceResult
    func clientLifecycle() -> GrainClientLifecycle
}

extension GrainClient: ScannerWorkflowClient {}

public struct ScannerShellState: Equatable, Sendable {
    public var qrString: String
    public var trustAnchorID: String
    public var previewStatus: GrainScanPreviewStatus?
    public var acceptStatus: GrainScanAcceptStatus?
    public var diagnostics: [String]
    public var canAccept: Bool
    public var acceptedCount: Int
    public var acceptedScanID: String?
    public var lifecycleStatus: String?
    public var deviceCount: UInt64
    public var lifecycleEventCount: UInt64
    public var snapshotStatus: String?

    public init(
        qrString: String = "",
        trustAnchorID: String = "",
        previewStatus: GrainScanPreviewStatus? = nil,
        acceptStatus: GrainScanAcceptStatus? = nil,
        diagnostics: [String] = [],
        canAccept: Bool = false,
        acceptedCount: Int = 0,
        acceptedScanID: String? = nil,
        lifecycleStatus: String? = nil,
        deviceCount: UInt64 = 0,
        lifecycleEventCount: UInt64 = 0,
        snapshotStatus: String? = nil
    ) {
        self.qrString = qrString
        self.trustAnchorID = trustAnchorID
        self.previewStatus = previewStatus
        self.acceptStatus = acceptStatus
        self.diagnostics = diagnostics
        self.canAccept = canAccept
        self.acceptedCount = acceptedCount
        self.acceptedScanID = acceptedScanID
        self.lifecycleStatus = lifecycleStatus
        self.deviceCount = deviceCount
        self.lifecycleEventCount = lifecycleEventCount
        self.snapshotStatus = snapshotStatus
    }
}

@MainActor
public final class ScannerShellModel: ObservableObject {
    @Published public private(set) var state: ScannerShellState

    private let client: ScannerWorkflowClient
    private let trustProvider: any GrainTrustProvider
    private let snapshotCoordinator: GrainSnapshotCoordinator?

    public init(
        client: ScannerWorkflowClient = GrainClient(),
        trustProvider: any GrainTrustProvider = GrainStaticTrustProvider(anchors: [:]),
        snapshotPersistence: (any GrainSnapshotPersistence)? = nil
    ) {
        self.client = client
        self.trustProvider = trustProvider
        if let snapshotPersistence {
            self.snapshotCoordinator = GrainSnapshotCoordinator(persistence: snapshotPersistence)
        } else {
            self.snapshotCoordinator = nil
        }
        self.state = ScannerShellState()
    }

    public func updateQrString(_ value: String) {
        state.qrString = value
        resetDecisionState()
    }

    public func updateTrustAnchorID(_ value: String) {
        state.trustAnchorID = value
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
        if device.diag.isEmpty {
            persistSnapshot()
        }
    }

    public func preview() {
        let preview = client.scanPreview(
            qrString: state.qrString,
            trustAnchorID: normalizedTrustAnchorID(),
            trustProvider: trustProvider
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
            if state.previewStatus != .rejected || state.diagnostics.isEmpty {
                state.diagnostics = [scannerAcceptRequiresVerifiedPreviewDiag]
            }
            state.acceptStatus = nil
            state.acceptedScanID = nil
            state.canAccept = false
            return
        }

        let accepted = client.scanAccept(
            qrString: state.qrString,
            trustAnchorID: normalizedTrustAnchorID(),
            trustProvider: trustProvider
        )
        state.acceptStatus = accepted.status
        state.acceptedScanID = accepted.scanID
        state.diagnostics = accepted.diag
        state.acceptedCount = client.listAcceptedScans().count
        state.canAccept = state.previewStatus == .verified
        if accepted.status == .accepted || accepted.status == .alreadyAccepted {
            persistSnapshot()
        }
    }

    public func restorePersistedSnapshot() {
        guard let snapshotCoordinator else {
            return
        }
        do {
            guard let restored = try snapshotCoordinator.restore(into: client) else {
                state.snapshotStatus = "Empty"
                refreshLifecycle()
                state.acceptedCount = client.listAcceptedScans().count
                return
            }
            state.snapshotStatus = restored.status
            state.diagnostics = restored.diag
            state.acceptedCount = Int(restored.acceptedRecordCount)
            refreshLifecycle()
        } catch {
            state.snapshotStatus = "PersistenceError"
            state.diagnostics = [scannerSnapshotPersistenceDiag]
        }
    }

    private func normalizedTrustAnchorID() -> String {
        state.trustAnchorID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func persistSnapshot() {
        guard let snapshotCoordinator else {
            return
        }
        do {
            let exported = try snapshotCoordinator.persist(from: client)
            state.snapshotStatus = exported.status
            if !exported.diag.isEmpty {
                state.diagnostics = exported.diag
            }
        } catch {
            state.snapshotStatus = "PersistenceError"
            state.diagnostics = [scannerSnapshotPersistenceDiag]
        }
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
