package dev.grain.examples.androidreferenceapp

import dev.grain.android.GrainFileSnapshotPersistence
import java.nio.file.Files

fun main() {
    referenceAppBootsScansPersistsExportsAndRestores()
    println("Android reference app smoke: PASS")
}

private fun referenceAppBootsScansPersistsExportsAndRestores() {
    val snapshotDir = Files.createTempDirectory("grain-android-reference-snapshot")
    val snapshotPersistence = GrainFileSnapshotPersistence(snapshotDir.resolve("client-store.snapshot"))

    try {
        val configuration = GrainReferenceAppResources.bundled(
            snapshotPersistence = snapshotPersistence,
        )

        GrainReferenceScannerSession(configuration).use { session ->
            session.start()
            val controller = requireNotNull(session.controller) { "reference app did not create scanner controller" }

            requireSmoke(session.launchDiagnostic == null, "reference app launch diagnostic was set")
            requireSmoke(controller.state.lifecycleStatus == "Ready", "reference app did not prepare local identity")
            requireSmoke(controller.state.deviceCount == 2UL, "reference app device count mismatch")

            session.loadDemoScanAndPreview()
            requireSmoke(controller.state.previewStatus?.rawValue == "Verified", "demo QR did not verify")
            requireSmoke(controller.state.canAccept, "verified demo QR did not enable accept")
            session.acceptVerifiedPreview()
            requireSmoke(controller.state.acceptStatus?.rawValue == "Accepted", "demo QR was not accepted")
            requireSmoke(controller.state.acceptedCount == 1, "accepted scan count mismatch")
            requireSmoke(controller.state.snapshotStatus == "Exported", "accepted scan did not persist snapshot")

            val exported = session.exportAcceptedScansForShare()
            requireSmoke(exported?.status == "Exported", "sync export status mismatch")
            requireSmoke(controller.state.exportStatus == "Exported", "reference app did not expose export status")
            requireSmoke(controller.state.exportAcceptedCount == 1UL, "sync export accepted count mismatch")
        }

        GrainReferenceScannerSession(configuration).use { restoredSession ->
            restoredSession.start()
            val restoredController =
                requireNotNull(restoredSession.controller) { "reference app did not restore scanner controller" }
            requireSmoke(restoredController.state.snapshotStatus == "Restored", "reference app did not restore snapshot")
            requireSmoke(restoredController.state.acceptedCount == 1, "restored scan count mismatch")

            restoredSession.loadDemoScanAndPreview()
            restoredSession.acceptVerifiedPreview()
            requireSmoke(
                restoredController.state.acceptStatus?.rawValue == "AlreadyAccepted",
                "restored accept was not idempotent",
            )
            requireSmoke(restoredController.state.acceptedCount == 1, "restored accept duplicated scan")
        }

        val demoState = GrainAndroidReferenceApp.runDemo(configuration)
        requireSmoke(demoState.lifecycleStatus == "Ready", "demo app lifecycle status mismatch")
        requireSmoke(demoState.acceptedCount == 1, "demo app accepted count mismatch")
        requireSmoke(demoState.exportStatus == "Exported", "demo app export status mismatch")
    } finally {
        snapshotDir.toFile().deleteRecursively()
    }
}

private fun requireSmoke(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
