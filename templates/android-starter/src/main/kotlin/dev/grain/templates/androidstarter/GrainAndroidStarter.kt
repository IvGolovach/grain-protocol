package dev.grain.templates.androidstarter

import dev.grain.GrainSyncResult
import dev.grain.android.GrainSnapshotPersistence
import dev.grain.examples.androidscanner.CameraScanPayload
import dev.grain.examples.androidscanner.CameraScanSource
import dev.grain.examples.androidscanner.GrainScannerWorkflowClient
import dev.grain.examples.androidscanner.ScannerController
import dev.grain.examples.androidscanner.scannerTrustProviderFromBundleStream
import java.io.InputStream

data class GrainAndroidStarterState(
    val previewStatus: String?,
    val acceptStatus: String?,
    val acceptedScanIds: List<String>,
    val snapshotStatus: String?,
    val exportStatus: String?,
)

data class GrainAndroidStarterConfiguration(
    val openTrustAnchorBundle: () -> InputStream,
    val trustAnchorId: String,
    val snapshotPersistence: GrainSnapshotPersistence,
)

class GrainAndroidStarter(
    configuration: GrainAndroidStarterConfiguration,
) : AutoCloseable {
    private val client = GrainScannerWorkflowClient()
    private val controller = ScannerController(
        client = client,
        trustProvider = scannerTrustProviderFromBundleStream(configuration.openTrustAnchorBundle()),
        snapshotPersistence = configuration.snapshotPersistence,
    )

    init {
        controller.updateTrustAnchorId(configuration.trustAnchorId)
        controller.restorePersistedSnapshot()
        controller.prepareLocalIdentity(rootLabel = "android-starter", deviceLabel = "phone")
    }

    fun paste(qrString: String): GrainAndroidStarterState {
        controller.receiveCameraPayload(CameraScanPayload(qrString = qrString, source = CameraScanSource.Injected))
        return state()
    }

    fun preview(): GrainAndroidStarterState {
        controller.preview()
        return state()
    }

    fun acceptVerifiedPreview(): GrainAndroidStarterState {
        controller.accept()
        return state()
    }

    fun restore(): GrainAndroidStarterState {
        controller.restorePersistedSnapshot()
        return state()
    }

    fun listAcceptedScanIds(): List<String> =
        controller.state.acceptedScans.map { it.scanId }

    fun exportForShare(): GrainSyncResult =
        controller.exportSyncBundleForShare()

    fun state(): GrainAndroidStarterState =
        GrainAndroidStarterState(
            previewStatus = controller.state.previewStatus?.rawValue,
            acceptStatus = controller.state.acceptStatus?.rawValue,
            acceptedScanIds = listAcceptedScanIds(),
            snapshotStatus = controller.state.snapshotStatus,
            exportStatus = controller.state.exportStatus,
        )

    override fun close() {
        client.close()
    }
}

object GrainAndroidStarterResources {
    fun configuration(snapshotPersistence: GrainSnapshotPersistence): GrainAndroidStarterConfiguration =
        GrainAndroidStarterConfiguration(
            openTrustAnchorBundle = { openResource("TRUST-ANCHOR-BUNDLE-0001.json") },
            trustAnchorId = "fixture:primary",
            snapshotPersistence = snapshotPersistence,
        )

    fun sampleQrString(): String =
        openResource("SAMPLE-GR1.txt").bufferedReader(Charsets.UTF_8).use { it.readText() }.trim()

    private fun openResource(name: String): InputStream =
        requireNotNull(GrainAndroidStarterResources::class.java.classLoader.getResourceAsStream(name)) {
            "SDK_ERR_ANDROID_STARTER_RESOURCE_MISSING:$name"
        }
}
