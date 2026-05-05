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

const val SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG =
    "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_VERIFIED_PREVIEW"
const val SCANNER_ACCEPT_REQUIRES_TRUST_DIAG = "SDK_ERR_EXAMPLE_ACCEPT_REQUIRES_TRUST"

interface ScannerWorkflowClient {
    fun scanPreview(qrString: String, trustPubB64: String? = null): GrainScanPreview
    fun scanAccept(qrString: String, trustPubB64: String): GrainScanAccept
    fun listAcceptedScans(): List<GrainAcceptedScan>
    fun createRootIdentity(label: String = "root"): GrainIdentityResult
    fun addDeviceKey(label: String = "device"): GrainDeviceResult
    fun clientLifecycle(): GrainClientLifecycle
}

class GrainScannerWorkflowClient(
    private val client: GrainClient = GrainClient(),
) : ScannerWorkflowClient, AutoCloseable {
    override fun scanPreview(qrString: String, trustPubB64: String?): GrainScanPreview =
        client.scanPreview(qrString = qrString, trustPubB64 = trustPubB64)

    override fun scanAccept(qrString: String, trustPubB64: String): GrainScanAccept =
        client.scanAccept(qrString = qrString, trustPubB64 = trustPubB64)

    override fun listAcceptedScans(): List<GrainAcceptedScan> =
        client.listAcceptedScans()

    override fun createRootIdentity(label: String): GrainIdentityResult =
        client.createRootIdentity(label = label)

    override fun addDeviceKey(label: String): GrainDeviceResult =
        client.addDeviceKey(label = label)

    override fun clientLifecycle(): GrainClientLifecycle =
        client.clientLifecycle()

    override fun close() {
        client.close()
    }
}

data class ScannerUiState(
    val qrString: String = "",
    val trustPubB64: String = "",
    val previewStatus: GrainScanPreviewStatus? = null,
    val acceptStatus: GrainScanAcceptStatus? = null,
    val diagnostics: List<String> = emptyList(),
    val canAccept: Boolean = false,
    val acceptedCount: Int = 0,
    val acceptedScanId: String? = null,
    val lifecycleStatus: String? = null,
    val deviceCount: ULong = 0UL,
    val lifecycleEventCount: ULong = 0UL,
)

class ScannerController(
    private val client: ScannerWorkflowClient,
) {
    var state: ScannerUiState = ScannerUiState()
        private set

    fun updateQrString(value: String) {
        state = state.copy(qrString = value).withoutDecision()
    }

    fun updateTrustPubB64(value: String) {
        state = state.copy(trustPubB64 = value).withoutDecision()
    }

    fun receiveCameraPayload(payload: CameraScanPayload) {
        state = state.copy(qrString = payload.qrString).withoutDecision()
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
    }

    fun preview() {
        val preview = client.scanPreview(
            qrString = state.qrString,
            trustPubB64 = normalizedTrustInput(),
        )

        state = state.copy(
            previewStatus = preview.status,
            acceptStatus = null,
            diagnostics = preview.diag,
            canAccept = preview.status == GrainScanPreviewStatus.Verified,
            acceptedCount = client.listAcceptedScans().size,
            acceptedScanId = null,
        )
    }

    fun accept() {
        if (state.previewStatus != GrainScanPreviewStatus.Verified || !state.canAccept) {
            state = state.copy(
                acceptStatus = null,
                diagnostics = listOf(SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG),
                canAccept = false,
                acceptedScanId = null,
            )
            return
        }

        val trustPubB64 = normalizedTrustInput()
        if (trustPubB64 == null) {
            state = state.copy(
                acceptStatus = null,
                diagnostics = listOf(SCANNER_ACCEPT_REQUIRES_TRUST_DIAG),
                canAccept = false,
                acceptedScanId = null,
            )
            return
        }

        val accepted = client.scanAccept(qrString = state.qrString, trustPubB64 = trustPubB64)
        state = state.copy(
            acceptStatus = accepted.status,
            diagnostics = accepted.diag,
            acceptedCount = client.listAcceptedScans().size,
            acceptedScanId = accepted.scanId,
            canAccept = state.previewStatus == GrainScanPreviewStatus.Verified,
        )
    }

    private fun normalizedTrustInput(): String? =
        state.trustPubB64.trim().ifEmpty { null }

    private fun ScannerUiState.withoutDecision(): ScannerUiState =
        copy(
            previewStatus = null,
            acceptStatus = null,
            diagnostics = emptyList(),
            canAccept = false,
            acceptedScanId = null,
        )

    private fun ScannerUiState.withLifecycle(lifecycle: GrainClientLifecycle): ScannerUiState =
        copy(
            lifecycleStatus = lifecycle.status,
            deviceCount = lifecycle.deviceCount,
            lifecycleEventCount = lifecycle.lifecycleEventCount,
        )
}
