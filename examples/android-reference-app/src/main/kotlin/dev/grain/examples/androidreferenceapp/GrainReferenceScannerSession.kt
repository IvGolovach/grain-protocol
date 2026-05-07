package dev.grain.examples.androidreferenceapp

import dev.grain.GrainSyncResult
import dev.grain.examples.androidscanner.CameraScanPayload
import dev.grain.examples.androidscanner.CameraScanSource
import dev.grain.examples.androidscanner.ScannerController

const val ANDROID_REFERENCE_START_FAILED_DIAG =
    "SDK_ERR_ANDROID_REFERENCE_START_FAILED"
const val ANDROID_REFERENCE_DEMO_QR_MISSING_DIAG =
    "SDK_ERR_ANDROID_REFERENCE_DEMO_QR_MISSING"

class GrainReferenceScannerSession(
    val configuration: GrainReferenceAppConfiguration,
) : AutoCloseable {
    private var handle: GrainReferenceScannerHandle? = null
    private var started = false

    var controller: ScannerController? = null
        private set
    var launchDiagnostic: String? = null
        private set

    fun start() {
        if (started) {
            return
        }
        started = true

        try {
            val scannerHandle = GrainReferenceScannerFactory.makeHandle(configuration)
            scannerHandle.controller.restorePersistedSnapshot()
            scannerHandle.controller.prepareLocalIdentity(
                rootLabel = "android-reference",
                deviceLabel = "phone",
            )
            handle = scannerHandle
            controller = scannerHandle.controller
            launchDiagnostic = null
        } catch (_: RuntimeException) {
            handle?.close()
            handle = null
            controller = null
            launchDiagnostic = ANDROID_REFERENCE_START_FAILED_DIAG
        }
    }

    fun restorePersistedSnapshot() {
        controller?.restorePersistedSnapshot()
    }

    fun loadDemoScanAndPreview() {
        val qrString = configuration.demoQrString
        if (qrString.isNullOrBlank()) {
            launchDiagnostic = ANDROID_REFERENCE_DEMO_QR_MISSING_DIAG
            return
        }

        controller?.receiveCameraPayload(
            CameraScanPayload(qrString = qrString, source = CameraScanSource.Injected),
        )
        controller?.preview()
        launchDiagnostic = null
    }

    fun acceptVerifiedPreview() {
        controller?.accept()
    }

    fun exportAcceptedScansForShare(): GrainSyncResult? =
        controller?.exportSyncBundleForShare()

    override fun close() {
        handle?.close()
        handle = null
        controller = null
        started = false
    }
}
