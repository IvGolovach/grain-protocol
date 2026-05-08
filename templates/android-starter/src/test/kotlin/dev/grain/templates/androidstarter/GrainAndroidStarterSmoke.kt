package dev.grain.templates.androidstarter

import dev.grain.android.GrainFileSnapshotPersistence
import java.nio.file.Files

fun main() {
    starterPreviewsAcceptsPersistsAndRestores()
    println("Android starter smoke: PASS")
}

private fun starterPreviewsAcceptsPersistsAndRestores() {
    val snapshotDir = Files.createTempDirectory("grain-android-starter-snapshot")
    val snapshotFile = snapshotDir.resolve("client-store.snapshot")
    val persistence = GrainFileSnapshotPersistence(snapshotFile)
    val qrString = GrainAndroidStarterResources.sampleQrString()

    try {
        GrainAndroidStarter(GrainAndroidStarterResources.configuration(persistence)).use { starter ->
            requireSmoke(qrString.startsWith("GR1:"), "sample QR missing")
            requireSmoke(starter.state().snapshotStatus == "Exported", "starter did not persist identity snapshot")

            starter.paste(qrString)
            val preview = starter.preview()
            requireSmoke(preview.previewStatus == "Verified", "starter preview did not verify")

            val accepted = starter.acceptVerifiedPreview()
            requireSmoke(accepted.acceptStatus == "Accepted", "starter accept did not write scan")
            requireSmoke(accepted.acceptedScanIds.size == 1, "starter accepted scan count mismatch")
            requireSmoke(accepted.snapshotStatus == "Exported", "starter did not persist accepted scan")

            val exported = starter.exportForShare()
            requireSmoke(exported.status == "Exported", "starter export status mismatch")
        }

        GrainAndroidStarter(GrainAndroidStarterResources.configuration(persistence)).use { restored ->
            val restoredState = restored.restore()
            requireSmoke(restoredState.acceptedScanIds.size == 1, "starter restore did not load accepted scan")
            restored.paste(qrString)
            restored.preview()
            val acceptedAgain = restored.acceptVerifiedPreview()
            requireSmoke(acceptedAgain.acceptStatus == "AlreadyAccepted", "starter repeat accept was not idempotent")
            requireSmoke(acceptedAgain.acceptedScanIds.size == 1, "starter repeat accept duplicated scan")
        }
    } finally {
        snapshotDir.toFile().deleteRecursively()
    }
}

private fun requireSmoke(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
