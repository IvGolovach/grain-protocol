import Combine
import Foundation
import GrainClient
import GrainClientIOSAdapters

public let scannerAcceptRequiresVerifiedPreviewDiag = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW"
public let scannerSnapshotPersistenceDiag = "SDK_ERR_EXAMPLE_SNAPSHOT_PERSISTENCE"

public protocol ScannerWorkflowClient: GrainSnapshotClient {
    func scanPreview(
        handoff: GrainScanHandoff,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanPreview
    func scanAccept(
        handoff: GrainScanHandoff,
        trustProvider: any GrainTrustProvider
    ) -> GrainScanAccept
    func listAcceptedScans() -> [GrainAcceptedScan]
    func exportSyncBundle() -> GrainSyncResult
    func createRootIdentity(label: String) -> GrainIdentityResult
    func addDeviceKey(label: String) -> GrainDeviceResult
    func clientLifecycle() -> GrainClientLifecycle
}

extension GrainClient: ScannerWorkflowClient {}

public enum ScannerShellConfigurationError: Error, Equatable, Sendable {
    case nonFileTrustAnchorBundleURL
}

public struct ScannerAcceptedScanSummary: Equatable, Identifiable, Sendable {
    public let id: String

    public init(scanID: String) {
        self.id = scanID
    }
}

public struct ScannerExportDebugSummary: Equatable, Sendable {
    public let status: String
    public let acceptedRecordCount: UInt64
    public let deviceCount: UInt64
    public let lifecycleEventCount: UInt64
    public let diagnostics: [String]

    public init(
        status: String,
        acceptedRecordCount: UInt64,
        deviceCount: UInt64,
        lifecycleEventCount: UInt64,
        diagnostics: [String]
    ) {
        self.status = status
        self.acceptedRecordCount = acceptedRecordCount
        self.deviceCount = deviceCount
        self.lifecycleEventCount = lifecycleEventCount
        self.diagnostics = diagnostics
    }
}

public struct ScannerShellState: Equatable, Sendable {
    public var qrString: String
    public var trustAnchorID: String
    public var previewStatus: GrainScanPreviewStatus?
    public var acceptStatus: GrainScanAcceptStatus?
    public var scanSource: CameraScanSource?
    public var diagnostics: [String]
    public var canAccept: Bool
    public var acceptedCount: Int
    public var acceptedScanID: String?
    public var acceptedScans: [ScannerAcceptedScanSummary]
    public var lifecycleStatus: String?
    public var deviceCount: UInt64
    public var lifecycleEventCount: UInt64
    public var snapshotStatus: String?
    public var exportStatus: String?
    public var exportAcceptedCount: UInt64
    public var exportDeviceCount: UInt64
    public var exportLifecycleEventCount: UInt64

    public init(
        qrString: String = "",
        trustAnchorID: String = "",
        previewStatus: GrainScanPreviewStatus? = nil,
        acceptStatus: GrainScanAcceptStatus? = nil,
        scanSource: CameraScanSource? = nil,
        diagnostics: [String] = [],
        canAccept: Bool = false,
        acceptedCount: Int = 0,
        acceptedScanID: String? = nil,
        acceptedScans: [ScannerAcceptedScanSummary] = [],
        lifecycleStatus: String? = nil,
        deviceCount: UInt64 = 0,
        lifecycleEventCount: UInt64 = 0,
        snapshotStatus: String? = nil,
        exportStatus: String? = nil,
        exportAcceptedCount: UInt64 = 0,
        exportDeviceCount: UInt64 = 0,
        exportLifecycleEventCount: UInt64 = 0
    ) {
        self.qrString = qrString
        self.trustAnchorID = trustAnchorID
        self.previewStatus = previewStatus
        self.acceptStatus = acceptStatus
        self.scanSource = scanSource
        self.diagnostics = diagnostics
        self.canAccept = canAccept
        self.acceptedCount = acceptedCount
        self.acceptedScanID = acceptedScanID
        self.acceptedScans = acceptedScans
        self.lifecycleStatus = lifecycleStatus
        self.deviceCount = deviceCount
        self.lifecycleEventCount = lifecycleEventCount
        self.snapshotStatus = snapshotStatus
        self.exportStatus = exportStatus
        self.exportAcceptedCount = exportAcceptedCount
        self.exportDeviceCount = exportDeviceCount
        self.exportLifecycleEventCount = exportLifecycleEventCount
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
        snapshotPersistence: (any GrainSnapshotPersistence)? = nil,
        initialTrustAnchorID: String = ""
    ) {
        self.client = client
        self.trustProvider = trustProvider
        if let snapshotPersistence {
            self.snapshotCoordinator = GrainSnapshotCoordinator(persistence: snapshotPersistence)
        } else {
            self.snapshotCoordinator = nil
        }
        self.state = ScannerShellState(trustAnchorID: initialTrustAnchorID)
    }

    public convenience init(
        trustAnchorBundleJSON: String,
        initialTrustAnchorID: String,
        snapshotPersistence: any GrainSnapshotPersistence
    ) throws {
        try self.init(
            trustProvider: GrainStaticTrustProvider(bundleJSON: trustAnchorBundleJSON),
            snapshotPersistence: snapshotPersistence,
            initialTrustAnchorID: initialTrustAnchorID
        )
    }

    public convenience init(
        trustAnchorBundleURL: URL,
        initialTrustAnchorID: String,
        snapshotPersistence: any GrainSnapshotPersistence
    ) throws {
        let bundleJSON = try loadLocalTrustAnchorBundleJSON(from: trustAnchorBundleURL)
        try self.init(
            trustAnchorBundleJSON: bundleJSON,
            initialTrustAnchorID: initialTrustAnchorID,
            snapshotPersistence: snapshotPersistence
        )
    }

    public func updateQrString(_ value: String) {
        state.qrString = value
        state.scanSource = nil
        resetDecisionState()
    }

    public func clearScanInput() {
        state.qrString = ""
        state.scanSource = nil
        resetDecisionState()
    }

    public func updateTrustAnchorID(_ value: String) {
        state.trustAnchorID = value
        resetDecisionState()
    }

    public func receiveCameraPayload(_ payload: CameraScanPayload) {
        state.qrString = payload.qrString
        state.scanSource = payload.source
        resetDecisionState()
    }

    @discardableResult
    public func captureNextCameraPayload(from adapter: any CameraScanAdapter) async throws -> CameraScanPayload? {
        guard let payload = try await adapter.nextScanPayload() else {
            return nil
        }
        receiveCameraPayload(payload)
        return payload
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
            handoff: currentScanHandoff(),
            trustProvider: trustProvider
        )

        state.previewStatus = preview.status
        state.acceptStatus = nil
        state.acceptedScanID = nil
        state.diagnostics = preview.diag
        state.canAccept = preview.status == .verified
        refreshAcceptedScans()
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
            handoff: currentScanHandoff(),
            trustProvider: trustProvider
        )
        state.acceptStatus = accepted.status
        state.acceptedScanID = accepted.scanID
        state.diagnostics = accepted.diag
        refreshAcceptedScans()
        state.canAccept = state.previewStatus == .verified
        if accepted.status == .accepted || accepted.status == .alreadyAccepted {
            persistSnapshot()
        }
    }

    public func refreshAcceptedScans() {
        let scans = client.listAcceptedScans()
        state.acceptedScans = scans.map { ScannerAcceptedScanSummary(scanID: $0.scanID) }
        state.acceptedCount = scans.count
    }

    @discardableResult
    public func exportSyncBundleForShare() -> GrainSyncResult {
        let exported = client.exportSyncBundle()
        applyExportDebugState(exported)
        return exported
    }

    @discardableResult
    public func exportDebugSummary() -> ScannerExportDebugSummary {
        let exported = client.exportSyncBundle()
        applyExportDebugState(exported)
        return ScannerExportDebugSummary(
            status: exported.status,
            acceptedRecordCount: exported.acceptedRecordCount,
            deviceCount: exported.deviceCount,
            lifecycleEventCount: exported.lifecycleEventCount,
            diagnostics: exported.diag
        )
    }

    public func restorePersistedSnapshot() {
        guard let snapshotCoordinator else {
            return
        }
        do {
            guard let restored = try snapshotCoordinator.restore(into: client) else {
                state.snapshotStatus = "Empty"
                refreshLifecycle()
                refreshAcceptedScans()
                return
            }
            state.snapshotStatus = restored.status
            state.diagnostics = restored.diag
            refreshAcceptedScans()
            refreshLifecycle()
        } catch {
            state.snapshotStatus = "PersistenceError"
            state.diagnostics = [scannerSnapshotPersistenceDiag]
        }
    }

    private func normalizedTrustAnchorID() -> String {
        state.trustAnchorID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentScanHandoff() -> GrainScanHandoff {
        GrainScanHandoff(
            qrString: state.qrString,
            trustAnchorID: normalizedTrustAnchorID(),
            source: grainHandoffSource(from: state.scanSource)
        )
    }

    private func grainHandoffSource(from source: CameraScanSource?) -> GrainScanHandoffSource {
        switch source {
        case .camera:
            return .camera
        case .injected:
            return .injected
        case nil:
            return .manualEntry
        }
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

    private func applyExportDebugState(_ exported: GrainSyncResult) {
        state.exportStatus = exported.status
        state.exportAcceptedCount = exported.acceptedRecordCount
        state.exportDeviceCount = exported.deviceCount
        state.exportLifecycleEventCount = exported.lifecycleEventCount
        state.diagnostics = exported.diag
    }

    private func resetDecisionState() {
        state.previewStatus = nil
        state.acceptStatus = nil
        state.acceptedScanID = nil
        state.diagnostics = []
        state.canAccept = false
    }
}

#if canImport(Security)
public extension ScannerShellModel {
    convenience init(
        keychainBackedTrustAnchorBundleJSON bundleJSON: String,
        initialTrustAnchorID: String,
        snapshotService: String = "dev.grain.ios-scanner.snapshot",
        snapshotAccount: String = "default",
        snapshotAccessGroup: String? = nil,
        snapshotAccessible: GrainKeychainAccessibility = .whenUnlockedThisDeviceOnly
    ) throws {
        try self.init(
            trustAnchorBundleJSON: bundleJSON,
            initialTrustAnchorID: initialTrustAnchorID,
            snapshotPersistence: GrainKeychainSnapshotPersistence(
                service: snapshotService,
                account: snapshotAccount,
                accessGroup: snapshotAccessGroup,
                accessible: snapshotAccessible
            )
        )
    }

    convenience init(
        keychainBackedTrustAnchorBundleURL bundleURL: URL,
        initialTrustAnchorID: String,
        snapshotService: String = "dev.grain.ios-scanner.snapshot",
        snapshotAccount: String = "default",
        snapshotAccessGroup: String? = nil,
        snapshotAccessible: GrainKeychainAccessibility = .whenUnlockedThisDeviceOnly
    ) throws {
        let bundleJSON = try loadLocalTrustAnchorBundleJSON(from: bundleURL)
        try self.init(
            keychainBackedTrustAnchorBundleJSON: bundleJSON,
            initialTrustAnchorID: initialTrustAnchorID,
            snapshotService: snapshotService,
            snapshotAccount: snapshotAccount,
            snapshotAccessGroup: snapshotAccessGroup,
            snapshotAccessible: snapshotAccessible
        )
    }
}
#endif

private func loadLocalTrustAnchorBundleJSON(from url: URL) throws -> String {
    guard url.isFileURL else {
        throw ScannerShellConfigurationError.nonFileTrustAnchorBundleURL
    }
    return try String(contentsOf: url, encoding: .utf8)
}
