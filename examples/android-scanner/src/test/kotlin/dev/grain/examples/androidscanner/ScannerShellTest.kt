package dev.grain.examples.androidscanner

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import dev.grain.GrainTrustAnchorBundleException
import dev.grain.android.GrainFileSnapshotPersistence
import dev.grain.android.GrainSnapshotPersistence
import java.io.ByteArrayInputStream
import kotlin.io.path.Path
import java.nio.file.Files

fun main() {
    acceptRequiresVerifiedPreview()
    localTrustAnchorBundleLoadsAndInvalidBundleFailsClosed()
    localTrustAnchorBundleStreamLoadsForAndroidAssetBoundary()
    cameraFrameAdapterFeedsControllerAndIgnoresEmptyFrames()
    verifiedPreviewEnablesAcceptAndPersistsSnapshot()
    blankTrustAnchorRejectsWithoutWrite()
    unknownTrustAnchorRejectsWithoutWrite()
    println("Android scanner shell smoke: PASS")
}

private fun acceptRequiresVerifiedPreview() {
    GrainScannerWorkflowClient().use { client ->
        val persistence = RecordingSnapshotPersistence()
        val controller = ScannerController(
            client = client,
            trustProvider = scannerTrustProviderFromLocalBundlePath(trustAnchorBundlePath()),
            snapshotPersistence = persistence,
        )

        controller.accept()

        requireSmoke(!controller.state.canAccept, "accept guard enabled accept")
        requireSmoke(controller.state.acceptStatus == null, "accept guard set accept status")
        requireSmoke(controller.state.acceptedCount == 0, "accept guard wrote accepted record")
        requireSmoke(persistence.saveCount == 0, "accept guard persisted snapshot")
        requireSmoke(
            controller.state.diagnostics == listOf(SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG),
            "accept guard diagnostics mismatch",
        )
    }
}

private fun localTrustAnchorBundleLoadsAndInvalidBundleFailsClosed() {
    val trustProvider = scannerTrustProviderFromLocalBundlePath(trustAnchorBundlePath())
    requireSmoke(trustProvider.trustPubB64(trustAnchorId()) == trustPubB64(), "local bundle trust mismatch")
    requireSmoke(trustProvider.trustPubB64("publisher:unknown") == null, "local bundle resolved unknown trust")

    try {
        scannerTrustProviderFromBundleJson("""{"bundle_v":1,"anchors":[]}""")
        error("invalid trust anchor bundle did not fail closed")
    } catch (_: GrainTrustAnchorBundleException) {
        // Expected.
    }

    try {
        scannerTrustProviderFromLocalBundlePath(trustAnchorBundlePath().parent.resolve("missing.json"))
        error("missing local trust anchor bundle did not fail closed")
    } catch (_: ScannerTrustAnchorBundleLoadException) {
        // Expected.
    }
}

private fun localTrustAnchorBundleStreamLoadsForAndroidAssetBoundary() {
    val bundleJson = Files.readString(trustAnchorBundlePath())
    val trustProvider = scannerTrustProviderFromBundleStream(
        ByteArrayInputStream(bundleJson.toByteArray(Charsets.UTF_8)),
    )

    requireSmoke(trustProvider.trustPubB64(trustAnchorId()) == trustPubB64(), "stream bundle trust mismatch")

    try {
        scannerTrustProviderFromBundleStream(
            ByteArrayInputStream("""{"bundle_v":1,"anchors":[]}""".toByteArray(Charsets.UTF_8)),
        )
        error("invalid stream trust anchor bundle did not fail closed")
    } catch (_: GrainTrustAnchorBundleException) {
        // Expected.
    }
}

private fun cameraFrameAdapterFeedsControllerAndIgnoresEmptyFrames() {
    val qrString = fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")

    GrainScannerWorkflowClient().use { client ->
        val controller = ScannerController(
            client = client,
            trustProvider = scannerTrustProviderFromLocalBundlePath(trustAnchorBundlePath()),
        )
        controller.updateQrString("manual-paste")

        val emptyAdapter = CameraXFrameScanAdapter<String> { null }
        requireSmoke(!controller.scanCameraFrame("empty-frame", emptyAdapter), "empty camera frame reported scan")
        requireSmoke(controller.state.qrString == "manual-paste", "empty camera frame cleared manual input")
        requireSmoke(controller.state.scanSource == null, "empty camera frame changed scan source")

        val cameraAdapter = CameraXFrameScanAdapter<String> { "  $qrString  " }
        requireSmoke(controller.scanCameraFrame("camera-frame", cameraAdapter), "camera frame did not report scan")
        requireSmoke(controller.state.qrString == qrString, "camera frame did not update QR input")
        requireSmoke(controller.state.scanSource == CameraScanSource.Camera, "camera frame did not record source")
        requireSmoke(controller.state.previewStatus == null, "camera frame kept stale preview")
        requireSmoke(!controller.state.canAccept, "camera frame kept stale accept gate")

        controller.updateQrString("manual-paste-again")
        requireSmoke(controller.state.scanSource == null, "manual paste did not clear scan source")
    }
}

private fun verifiedPreviewEnablesAcceptAndPersistsSnapshot() {
    val qrString = fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")
    val snapshotDir = Files.createTempDirectory("grain-android-scanner-snapshot")
    val snapshotPersistence = GrainFileSnapshotPersistence(snapshotDir.resolve("client-store.snapshot"))

    try {
        GrainScannerWorkflowClient().use { client ->
            val controller = scannerController(client, snapshotPersistence)
            controller.prepareLocalIdentity()
            requireSmoke(controller.state.lifecycleStatus == "Ready", "lifecycle status mismatch")
            requireSmoke(controller.state.deviceCount == 2UL, "device count mismatch")
            requireSmoke(controller.state.lifecycleEventCount == 1UL, "lifecycle event count mismatch")
            requireSmoke(controller.state.snapshotStatus == "Exported", "identity snapshot status mismatch")
            controller.prepareLocalIdentity()
            requireSmoke(controller.state.deviceCount == 2UL, "repeat prepare duplicated device")
            requireSmoke(controller.state.lifecycleEventCount == 1UL, "repeat prepare duplicated lifecycle event")

            controller.updateTrustAnchorId(trustAnchorId())
            val cameraAdapter = CameraXFrameScanAdapter<String> { frame -> frame }
            val cameraPayload = cameraAdapter.decode(qrString) ?: error("camera payload missing")
            controller.receiveCameraPayload(cameraPayload)

            controller.preview()

            requireSmoke(controller.state.previewStatus?.rawValue == "Verified", "preview status mismatch")
            requireSmoke(controller.state.canAccept, "verified preview did not enable accept")
            requireSmoke(controller.state.diagnostics.isEmpty(), "verified preview diagnostics not empty")

            controller.accept()

            requireSmoke(controller.state.acceptStatus?.rawValue == "Accepted", "accept status mismatch")
            requireSmoke(controller.state.acceptedCount == 1, "accepted count mismatch")
            requireSmoke(controller.state.acceptedScans.size == 1, "accepted scan list mismatch")
            requireSmoke(controller.state.acceptedScanId != null, "accepted scan id missing")
            requireSmoke(
                controller.state.acceptedScans.single().scanId == controller.state.acceptedScanId,
                "accepted scan summary id mismatch",
            )
            requireSmoke(controller.state.snapshotStatus == "Exported", "accept snapshot status mismatch")
            requireSmoke(snapshotPersistence.loadSnapshotB64() != null, "snapshot was not persisted")

            controller.refreshAcceptedScans()
            requireSmoke(controller.state.acceptedScans.size == 1, "refresh accepted scans mismatch")

            val exported = controller.exportSyncBundleForShare()
            requireSmoke(exported.status == "Exported", "sync export status mismatch")
            requireSmoke(exported.bundleB64 != null, "sync export bundle missing")
            requireSmoke(controller.state.exportStatus == "Exported", "sync export UI status mismatch")
            requireSmoke(controller.state.exportAcceptedCount == 1UL, "sync export accepted count mismatch")
            requireSmoke(controller.state.diagnostics.isEmpty(), "sync export diagnostics not empty")

            controller.accept()

            requireSmoke(controller.state.acceptStatus?.rawValue == "AlreadyAccepted", "repeat accept status mismatch")
            requireSmoke(controller.state.acceptedCount == 1, "repeat accept duplicated record")
            requireSmoke(controller.state.acceptedScans.size == 1, "repeat accept duplicated scan summary")
        }

        GrainScannerWorkflowClient().use { restartedClient ->
            val restarted = scannerController(restartedClient, snapshotPersistence)
            restarted.restorePersistedSnapshot()
            requireSmoke(restarted.state.snapshotStatus == "Restored", "restore snapshot status mismatch")
            requireSmoke(restarted.state.acceptedCount == 1, "restore accepted count mismatch")
            requireSmoke(restarted.state.acceptedScans.size == 1, "restore accepted scan list mismatch")
            requireSmoke(restarted.state.lifecycleStatus == "Ready", "restore lifecycle status mismatch")
        }
    } finally {
        snapshotDir.toFile().deleteRecursively()
    }
}

private fun blankTrustAnchorRejectsWithoutWrite() {
    rejectedTrustAnchorDoesNotWrite(trustAnchorId = "   ", expectedDiag = "SDK_ERR_TRUST_ANCHOR_REQUIRED")
}

private fun unknownTrustAnchorRejectsWithoutWrite() {
    rejectedTrustAnchorDoesNotWrite(trustAnchorId = "publisher:unknown", expectedDiag = "SDK_ERR_TRUST_ANCHOR_NOT_FOUND")
}

private fun rejectedTrustAnchorDoesNotWrite(trustAnchorId: String, expectedDiag: String) {
    val qrString = fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")

    GrainScannerWorkflowClient().use { client ->
        val persistence = RecordingSnapshotPersistence()
        val controller = ScannerController(
            client = client,
            trustProvider = scannerTrustProviderFromLocalBundlePath(trustAnchorBundlePath()),
            snapshotPersistence = persistence,
        )

        controller.updateTrustAnchorId(trustAnchorId)
        controller.receiveCameraPayload(CameraScanPayload(qrString = qrString, source = CameraScanSource.Injected))
        controller.preview()

        requireSmoke(controller.state.previewStatus?.rawValue == "Rejected", "trust preview did not reject")
        requireSmoke(controller.state.diagnostics == listOf(expectedDiag), "trust rejection diagnostics mismatch")
        requireSmoke(!controller.state.canAccept, "trust rejection enabled accept")

        controller.accept()

        requireSmoke(controller.state.acceptStatus == null, "trust rejection set accept status")
        requireSmoke(controller.state.acceptedCount == 0, "trust rejection wrote accepted record")
        requireSmoke(persistence.saveCount == 0, "trust rejection persisted snapshot")
        requireSmoke(controller.state.diagnostics == listOf(expectedDiag), "trust rejection diagnostic was overwritten")
    }
}

private fun scannerController(
    client: GrainScannerWorkflowClient,
    snapshotPersistence: GrainSnapshotPersistence,
): ScannerController =
    ScannerController(
        client = client,
        trustProvider = scannerTrustProviderFromLocalBundlePath(trustAnchorBundlePath()),
        snapshotPersistence = snapshotPersistence,
    )

private class RecordingSnapshotPersistence : GrainSnapshotPersistence {
    var saveCount: Int = 0
    private var snapshotB64: String? = null

    override fun loadSnapshotB64(): String? = snapshotB64

    override fun saveSnapshotB64(snapshotB64: String) {
        saveCount += 1
        this.snapshotB64 = snapshotB64
    }

    override fun clearSnapshot() {
        snapshotB64 = null
    }
}

private fun trustAnchorId(): String = "fixture:primary"

private fun trustPubB64(): String =
    fixtureString("sdk/trust/fixtures/TRUST-ANCHOR-BUNDLE-0001.json#/anchors/0/trust_pub_b64")

private fun trustAnchorBundlePath() =
    repoRoot().resolve("sdk/trust/fixtures/TRUST-ANCHOR-BUNDLE-0001.json")

private val mapper = jacksonObjectMapper()

private fun fixtureString(ref: String): String {
    val parts = ref.split("#", limit = 2)
    require(parts.size == 2 && parts[1].startsWith("/")) { "invalid ref: $ref" }

    val node: JsonNode = mapper.readTree(repoRoot().resolve(parts[0]).toFile()).at(parts[1])

    require(!node.isMissingNode && node.isTextual) { "invalid ref: $ref" }
    return node.asText()
}

private fun repoRoot() =
    Path(System.getProperty("grain.repoRoot")).toAbsolutePath().normalize()

private fun requireSmoke(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
