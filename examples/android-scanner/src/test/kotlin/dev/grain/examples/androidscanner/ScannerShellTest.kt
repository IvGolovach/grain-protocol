package dev.grain.examples.androidscanner

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import kotlin.io.path.Path

fun main() {
    acceptRequiresVerifiedPreview()
    verifiedPreviewEnablesAcceptAndPersistsOnce()
    println("Android scanner shell smoke: PASS")
}

private fun acceptRequiresVerifiedPreview() {
    GrainScannerWorkflowClient().use { client ->
        val controller = ScannerController(client)

        controller.accept()

        requireSmoke(!controller.state.canAccept, "accept guard enabled accept")
        requireSmoke(controller.state.acceptStatus == null, "accept guard set accept status")
        requireSmoke(
            controller.state.diagnostics == listOf(SCANNER_ACCEPT_REQUIRES_VERIFIED_PREVIEW_DIAG),
            "accept guard diagnostics mismatch",
        )
    }
}

private fun verifiedPreviewEnablesAcceptAndPersistsOnce() {
    val qrString = fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")
    val trustPubB64 = fixtureString("conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64")

    GrainScannerWorkflowClient().use { client ->
        val controller = ScannerController(client)
        controller.updateTrustPubB64(trustPubB64)
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

        controller.accept()

        requireSmoke(controller.state.acceptStatus?.rawValue == "AlreadyAccepted", "repeat accept status mismatch")
        requireSmoke(controller.state.acceptedCount == 1, "repeat accept duplicated record")
    }
}

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
