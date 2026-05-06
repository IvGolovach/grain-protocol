package dev.grain.examples.androidscanner

import dev.grain.GrainAcceptedScan
import dev.grain.GrainClient
import dev.grain.GrainClientLifecycle
import dev.grain.GrainDeviceResult
import dev.grain.GrainIdentityResult
import dev.grain.GrainScanAccept
import dev.grain.GrainScanAcceptStatus
import dev.grain.GrainScanPreview
import dev.grain.GrainScanPreviewStatus
import dev.grain.GrainStoreSnapshotResult
import dev.grain.GrainSyncResult
import dev.grain.GrainTrustProvider
import dev.grain.android.GrainSnapshotClient
import dev.grain.android.GrainSnapshotCoordinator
import dev.grain.android.GrainSnapshotPersistence

const val SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG =
    "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW"
const val SCANNER_SNAPSHOT_PERSISTENCE_DIAG = "SDK_ERR_EXAMPLE_SNAPSHOT_PERSISTENCE"

interface ScannerWorkflowClient : GrainSnapshotClient {
    fun scanPreview(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanPreview
    fun scanAccept(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanAccept
    fun listAcceptedScans(): List<GrainAcceptedScan>
    fun exportSyncBundle(): GrainSyncResult
    fun createRootIdentity(label: String = "root"): GrainIdentityResult
    fun addDeviceKey(label: String = "device"): GrainDeviceResult
    fun clientLifecycle(): GrainClientLifecycle
}

class GrainScannerWorkflowClient(
    private val client: GrainClient = GrainClient(),
) : ScannerWorkflowClient, AutoCloseable {
    override fun scanPreview(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanPreview =
        client.scanPreview(
            qrString = qrString,
            trustAnchorId = trustAnchorId,
            trustProvider = trustProvider,
        )

    override fun scanAccept(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanAccept =
        client.scanAccept(
            qrString = qrString,
            trustAnchorId = trustAnchorId,
            trustProvider = trustProvider,
        )

    override fun listAcceptedScans(): List<GrainAcceptedScan> =
        client.listAcceptedScans()

    override fun exportSyncBundle(): GrainSyncResult =
        client.exportSyncBundle()

    override fun createRootIdentity(label: String): GrainIdentityResult =
        client.createRootIdentity(label = label)

    override fun addDeviceKey(label: String): GrainDeviceResult =
        client.addDeviceKey(label = label)

    override fun clientLifecycle(): GrainClientLifecycle =
        client.clientLifecycle()

    override fun exportStoreSnapshot(): GrainStoreSnapshotResult =
        client.exportStoreSnapshot()

    override fun restoreStoreSnapshot(snapshotB64: String): GrainStoreSnapshotResult =
        client.restoreStoreSnapshot(snapshotB64 = snapshotB64)

    override fun close() {
        client.close()
    }
}

data class ScannerAcceptedScanSummary(
    val scanId: String,
)

data class ScannerUiState(
    val qrString: String = "",
    val trustAnchorId: String = "",
    val previewStatus: GrainScanPreviewStatus? = null,
    val acceptStatus: GrainScanAcceptStatus? = null,
    val scanSource: CameraScanSource? = null,
    val diagnostics: List<String> = emptyList(),
    val canAccept: Boolean = false,
    val acceptedCount: Int = 0,
    val acceptedScans: List<ScannerAcceptedScanSummary> = emptyList(),
    val acceptedScanId: String? = null,
    val lifecycleStatus: String? = null,
    val deviceCount: ULong = 0UL,
    val lifecycleEventCount: ULong = 0UL,
    val snapshotStatus: String? = null,
    val exportStatus: String? = null,
    val exportAcceptedCount: ULong = 0UL,
)

class ScannerController(
    private val client: ScannerWorkflowClient,
    private val trustProvider: GrainTrustProvider,
    snapshotPersistence: GrainSnapshotPersistence? = null,
) {
    private val snapshotCoordinator = snapshotPersistence?.let(::GrainSnapshotCoordinator)
    var state: ScannerUiState = ScannerUiState()
        private set

    fun updateQrString(value: String) {
        state = state.copy(qrString = value, scanSource = null).withoutDecision()
    }

    fun updateTrustAnchorId(value: String) {
        state = state.copy(trustAnchorId = value).withoutDecision()
    }

    fun receiveCameraPayload(payload: CameraScanPayload) {
        state = state.copy(qrString = payload.qrString, scanSource = payload.source).withoutDecision()
    }

    fun <FrameT> scanCameraFrame(
        frame: FrameT,
        cameraScanAdapter: CameraScanAdapter<FrameT>,
    ): Boolean {
        val payload = cameraScanAdapter.decode(frame) ?: return false
        receiveCameraPayload(payload)
        return true
    }

    fun prepareLocalIdentity(rootLabel: String = "phone", deviceLabel: String = "scanner") {
        val lifecycle = client.clientLifecycle()
        if (lifecycle.status == "Ready") {
            state = state.copy(diagnostics = lifecycle.diag).withLifecycle(lifecycle)
            return
        }
        if (lifecycle.status == "Uninitialized") {
            val root = client.createRootIdentity(label = rootLabel)
            if (root.diag.isNotEmpty()) {
                state = state.copy(diagnostics = root.diag).withLifecycle(client.clientLifecycle())
                return
            }
        }

        val device = client.addDeviceKey(label = deviceLabel)
        state = state
            .copy(diagnostics = device.diag)
            .withLifecycle(client.clientLifecycle())
        persistSnapshot()
    }

    fun preview() {
        val preview = client.scanPreview(
            qrString = state.qrString,
            trustAnchorId = normalizedTrustAnchorId(),
            trustProvider = trustProvider,
        )

        state = state.copy(
            previewStatus = preview.status,
            acceptStatus = null,
            diagnostics = preview.diag,
            canAccept = preview.status == GrainScanPreviewStatus.Verified,
            acceptedScanId = null,
        ).withAcceptedScans(client.listAcceptedScans())
    }

    fun accept() {
        if (state.previewStatus != GrainScanPreviewStatus.Verified || !state.canAccept) {
            val diagnostics = if (
                state.previewStatus == GrainScanPreviewStatus.Rejected &&
                state.diagnostics.isNotEmpty()
            ) {
                state.diagnostics
            } else {
                listOf(SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG)
            }
            state = state.copy(
                acceptStatus = null,
                diagnostics = diagnostics,
                canAccept = false,
                acceptedScanId = null,
            )
            return
        }

        val accepted = client.scanAccept(
            qrString = state.qrString,
            trustAnchorId = normalizedTrustAnchorId(),
            trustProvider = trustProvider,
        )
        val acceptedScans = client.listAcceptedScans()
        state = state.copy(
            acceptStatus = accepted.status,
            diagnostics = accepted.diag,
            acceptedScanId = accepted.scanId,
            canAccept = state.previewStatus == GrainScanPreviewStatus.Verified,
        ).withAcceptedScans(acceptedScans)
        if (
            accepted.status == GrainScanAcceptStatus.Accepted ||
            accepted.status == GrainScanAcceptStatus.AlreadyAccepted
        ) {
            persistSnapshot()
        }
    }

    fun refreshAcceptedScans() {
        state = state.withAcceptedScans(client.listAcceptedScans())
    }

    fun exportSyncBundleForShare(): GrainSyncResult {
        val exported = client.exportSyncBundle()
        state = state.copy(
            exportStatus = exported.status,
            exportAcceptedCount = exported.acceptedRecordCount,
            acceptedCount = exported.acceptedRecordCount.toInt(),
            diagnostics = if (exported.diag.isEmpty()) state.diagnostics else exported.diag,
        )
        return exported
    }

    fun restorePersistedSnapshot() {
        val coordinator = snapshotCoordinator ?: return
        try {
            val restored = coordinator.restore(client = client)
            if (restored == null) {
                state = state.copy(snapshotStatus = "Empty")
                refreshLifecycle()
                refreshAcceptedScans()
                return
            }
            state = state.copy(
                snapshotStatus = restored.status,
                diagnostics = restored.diag,
            )
            refreshLifecycle()
            refreshAcceptedScans()
        } catch (_: RuntimeException) {
            state = state.copy(
                snapshotStatus = "PersistenceError",
                diagnostics = listOf(SCANNER_SNAPSHOT_PERSISTENCE_DIAG),
            )
        }
    }

    private fun normalizedTrustAnchorId(): String =
        state.trustAnchorId.trim()

    private fun persistSnapshot() {
        val coordinator = snapshotCoordinator ?: return
        try {
            val exported = coordinator.persist(client = client)
            state = state.copy(
                snapshotStatus = exported.status,
                diagnostics = if (exported.diag.isEmpty()) state.diagnostics else exported.diag,
            )
        } catch (_: RuntimeException) {
            state = state.copy(
                snapshotStatus = "PersistenceError",
                diagnostics = listOf(SCANNER_SNAPSHOT_PERSISTENCE_DIAG),
            )
        }
    }

    private fun refreshLifecycle() {
        state = state.withLifecycle(client.clientLifecycle())
    }

    private fun ScannerUiState.withAcceptedScans(
        acceptedScans: List<GrainAcceptedScan>,
    ): ScannerUiState =
        copy(
            acceptedCount = acceptedScans.size,
            acceptedScans = acceptedScans.map { ScannerAcceptedScanSummary(scanId = it.scanId) },
        )

    private fun ScannerUiState.withoutDecision(): ScannerUiState =
        copy(
            previewStatus = null,
            acceptStatus = null,
            diagnostics = emptyList(),
            canAccept = false,
            acceptedScanId = null,
            exportStatus = null,
            exportAcceptedCount = 0UL,
        )

    private fun ScannerUiState.withLifecycle(lifecycle: GrainClientLifecycle): ScannerUiState =
        copy(
            lifecycleStatus = lifecycle.status,
            deviceCount = lifecycle.deviceCount,
            lifecycleEventCount = lifecycle.lifecycleEventCount,
        )
}
