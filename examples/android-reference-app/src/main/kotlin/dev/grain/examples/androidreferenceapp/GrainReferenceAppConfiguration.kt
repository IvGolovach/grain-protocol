package dev.grain.examples.androidreferenceapp

import dev.grain.android.GrainSnapshotPersistence
import dev.grain.examples.androidscanner.GrainScannerWorkflowClient
import dev.grain.examples.androidscanner.ScannerController
import dev.grain.examples.androidscanner.scannerTrustProviderFromBundleStream
import java.io.InputStream

const val ANDROID_REFERENCE_RESOURCE_MISSING_DIAG =
    "SDK_ERR_ANDROID_REFERENCE_RESOURCE_MISSING"

class GrainReferenceAppResourceException(resourceName: String) :
    IllegalArgumentException("$ANDROID_REFERENCE_RESOURCE_MISSING_DIAG:$resourceName")

data class GrainReferenceAppConfiguration(
    val openTrustAnchorBundle: () -> InputStream,
    val trustAnchorId: String,
    val snapshotPersistence: GrainSnapshotPersistence,
    val demoQrString: String?,
)

object GrainReferenceAppResources {
    fun bundled(snapshotPersistence: GrainSnapshotPersistence): GrainReferenceAppConfiguration =
        GrainReferenceAppConfiguration(
            openTrustAnchorBundle = { openResource("TRUST-ANCHOR-BUNDLE-0001.json") },
            trustAnchorId = "fixture:primary",
            snapshotPersistence = snapshotPersistence,
            demoQrString = readResourceText("POS-QR-001.txt").trim().ifEmpty { null },
        )

    private fun openResource(name: String): InputStream {
        val loader = GrainReferenceAppResources::class.java.classLoader
        return loader.getResourceAsStream(name)
            ?: throw GrainReferenceAppResourceException(name)
    }

    private fun readResourceText(name: String): String =
        openResource(name).bufferedReader(Charsets.UTF_8).use { it.readText() }
}

object GrainReferenceScannerFactory {
    fun makeHandle(configuration: GrainReferenceAppConfiguration): GrainReferenceScannerHandle {
        val client = GrainScannerWorkflowClient()
        val controller = ScannerController(
            client = client,
            trustProvider = scannerTrustProviderFromBundleStream(configuration.openTrustAnchorBundle()),
            snapshotPersistence = configuration.snapshotPersistence,
        )
        controller.updateTrustAnchorId(configuration.trustAnchorId)
        return GrainReferenceScannerHandle(controller = controller, client = client)
    }
}

class GrainReferenceScannerHandle(
    val controller: ScannerController,
    private val client: GrainScannerWorkflowClient,
) : AutoCloseable {
    override fun close() {
        client.close()
    }
}
