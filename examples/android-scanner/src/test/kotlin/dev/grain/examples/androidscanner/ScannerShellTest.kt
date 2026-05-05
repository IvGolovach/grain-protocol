package dev.grain.examples.androidscanner

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import dev.grain.GrainStaticTrustProvider
import dev.grain.android.GrainFileSnapshotPersistence
import dev.grain.android.GrainSnapshotPersistence
import kotlin.io.path.Path
import java.nio.file.Files

fun main() {
    acceptRequiresVerifiedPreview()
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
            trustProvider = GrainStaticTrustProvider(anchorId = trustAnchorId(), trustPubB64 = trustPubB64()),
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
            requireSmoke(controller.state.acceptedScanId != null, "accepted scan id missing")
            requireSmoke(controller.state.snapshotStatus == "Exported", "accept snapshot status mismatch")
            requireSmoke(snapshotPersistence.loadSnapshotB64() != null, "snapshot was not persisted")

            controller.accept()

            requireSmoke(controller.state.acceptStatus?.rawValue == "AlreadyAccepted", "repeat accept status mismatch")
            requireSmoke(controller.state.acceptedCount == 1, "repeat accept duplicated record")
        }

        GrainScannerWorkflowClient().use { restartedClient ->
            val restarted = scannerController(restartedClient, snapshotPersistence)
            restarted.restorePersistedSnapshot()
            requireSmoke(restarted.state.snapshotStatus == "Restored", "restore snapshot status mismatch")
            requireSmoke(restarted.state.acceptedCount == 1, "restore accepted count mismatch")
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
            trustProvider = GrainStaticTrustProvider(anchorId = trustAnchorId(), trustPubB64 = trustPubB64()),
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
        trustProvider = GrainStaticTrustProvider(anchorId = trustAnchorId(), trustPubB64 = trustPubB64()),
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

private fun trustAnchorId(): String = "publisher:primary"

private fun trustPubB64(): String =
    fixtureString("conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64")

private val mapper = jacksonObjectMapper()

private fun fixtureString(ref: String): String {
    val parts = ref.split("#", limit = 2)
    require(parts.size == 2 && parts[1].startsWith("/")) { "invalid ref: $ref" }

    val root = Path(System.getProperty("grain.repoRoot")).toAbsolutePath().normalize()
    var node: JsonNode = mapper.readTree(root.resolve(parts[0]).toFile())
    parts[1].drop(1).split("/").forEach { rawToken ->
        val token = rawToken.replace("~1", "/").replace("~0", "~")
        node = node.get(token) ?: error("invalid ref: $ref")
    }

    require(node.isTextual) { "invalid ref: $ref" }
    return node.asText()
}

private fun requireSmoke(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
