package dev.grain.examples.androidreferenceapp

import dev.grain.android.GrainFileSnapshotPersistence
import dev.grain.examples.androidscanner.CameraScanSource
import java.nio.file.Files

fun main() {
    referenceAppBootsScansPersistsExportsAndRestores()
    referenceAppManualPasteFlowMatchesDemoFlow()
    referenceAppReportsMissingManualQrWithoutPreview()
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
            requireSmoke(controller.state.snapshotStatus == "Exported", "local identity was not persisted")

            session.acceptVerifiedPreview()
            requireSmoke(!controller.state.canAccept, "accept was enabled before preview")
            requireSmoke(controller.state.acceptStatus == null, "accept before preview set accept status")
            requireSmoke(controller.state.acceptedCount == 0, "accept before preview wrote accepted scan")

            session.loadDemoScanAndPreview()
            requireSmoke(controller.state.previewStatus?.rawValue == "Verified", "demo QR did not verify")
            requireSmoke(controller.state.scanSource == CameraScanSource.Injected, "demo QR source mismatch")
            requireSmoke(controller.state.canAccept, "verified demo QR did not enable accept")
            session.acceptVerifiedPreview()
            requireSmoke(controller.state.acceptStatus?.rawValue == "Accepted", "demo QR was not accepted")
            requireSmoke(controller.state.acceptedCount == 1, "accepted scan count mismatch")
            requireSmoke(controller.state.acceptedScans.size == 1, "accepted scan list mismatch")
            requireSmoke(controller.state.acceptedScanId != null, "accepted scan id missing")
            requireSmoke(controller.state.snapshotStatus == "Exported", "accepted scan did not persist snapshot")

            val exported = requireNotNull(session.exportAcceptedScansForShare()) { "sync export summary missing" }
            requireSmoke(exported.status == "Exported", "sync export status mismatch")
            requireSmoke(exported.acceptedRecordCount == 1UL, "sync export accepted count mismatch")
            requireSmoke(exported.deviceCount == 2UL, "sync export device count mismatch")
            requireSmoke(exported.lifecycleEventCount == 1UL, "sync export lifecycle count mismatch")
            requireSmoke(exported.diagnostics.isEmpty(), "sync export diagnostics not empty")
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

            val restoredExport =
                requireNotNull(restoredSession.exportAcceptedScansForShare()) { "restored sync export summary missing" }
            requireSmoke(restoredExport.status == "Exported", "restored sync export status mismatch")
            requireSmoke(restoredExport.acceptedRecordCount == 1UL, "restored sync export accepted count mismatch")
        }

        val restoredState = GrainAndroidReferenceApp.restore(configuration)
        requireSmoke(restoredState.lifecycleStatus == "Ready", "app restore lifecycle status mismatch")
        requireSmoke(restoredState.acceptedCount == 1, "app restore accepted count mismatch")
        requireSmoke(restoredState.snapshotStatus == "Restored", "app restore snapshot status mismatch")
        requireSmoke(restoredState.exportSummary == null, "app restore exposed stale export summary")

        val demoState = GrainAndroidReferenceApp.runDemo(configuration)
        requireSmoke(demoState.lifecycleStatus == "Ready", "demo app lifecycle status mismatch")
        requireSmoke(demoState.previewStatus == "Verified", "demo app preview status mismatch")
        requireSmoke(demoState.acceptStatus == "AlreadyAccepted", "demo app idempotent accept status mismatch")
        requireSmoke(demoState.acceptedCount == 1, "demo app accepted count mismatch")
        val demoExport = requireNotNull(demoState.exportSummary) { "demo app export summary missing" }
        requireSmoke(demoExport.status == "Exported", "demo app export status mismatch")
        requireSmoke(demoExport.acceptedRecordCount == 1UL, "demo app export accepted count mismatch")
    } finally {
        snapshotDir.toFile().deleteRecursively()
    }
}

private fun referenceAppManualPasteFlowMatchesDemoFlow() {
    val snapshotDir = Files.createTempDirectory("grain-android-reference-manual-snapshot")
    val snapshotPersistence = GrainFileSnapshotPersistence(snapshotDir.resolve("client-store.snapshot"))

    try {
        val configuration = GrainReferenceAppResources.bundled(
            snapshotPersistence = snapshotPersistence,
        )
        val demoQrString = requireNotNull(configuration.demoQrString) { "demo QR resource missing" }

        val manualState = GrainAndroidReferenceApp.runManual(
            configuration = configuration,
            qrString = "\n  $demoQrString  \n",
        )

        requireSmoke(manualState.launchDiagnostic == null, "manual app launch diagnostic was set")
        requireSmoke(manualState.lifecycleStatus == "Ready", "manual app lifecycle status mismatch")
        requireSmoke(manualState.deviceCount == 2UL, "manual app device count mismatch")
        requireSmoke(manualState.lifecycleEventCount == 1UL, "manual app lifecycle count mismatch")
        requireSmoke(manualState.previewStatus == "Verified", "manual app preview status mismatch")
        requireSmoke(manualState.acceptStatus == "Accepted", "manual app accept status mismatch")
        requireSmoke(manualState.scanSource == null, "manual app did not use manual-entry source")
        requireSmoke(manualState.acceptedCount == 1, "manual app accepted count mismatch")
        requireSmoke(manualState.acceptedScanIds.size == 1, "manual app accepted list mismatch")
        requireSmoke(manualState.acceptedScanId == manualState.acceptedScanIds.single(), "manual app accepted id mismatch")
        requireSmoke(manualState.snapshotStatus == "Exported", "manual app snapshot status mismatch")
        val manualExport = requireNotNull(manualState.exportSummary) { "manual app export summary missing" }
        requireSmoke(manualExport.status == "Exported", "manual app export status mismatch")
        requireSmoke(manualExport.acceptedRecordCount == 1UL, "manual app export accepted count mismatch")
        requireSmoke(manualExport.deviceCount == 2UL, "manual app export device count mismatch")
        requireSmoke(manualExport.lifecycleEventCount == 1UL, "manual app export lifecycle count mismatch")
        requireSmoke(manualExport.diagnostics.isEmpty(), "manual app export diagnostics not empty")
        requireSmoke(manualState.diagnostics.isEmpty(), "manual app diagnostics not empty")

        val restoredState = GrainAndroidReferenceApp.restore(configuration)
        requireSmoke(restoredState.lifecycleStatus == "Ready", "manual restore lifecycle status mismatch")
        requireSmoke(restoredState.acceptedCount == 1, "manual restore accepted count mismatch")
        requireSmoke(restoredState.acceptedScanIds == manualState.acceptedScanIds, "manual restore accepted list mismatch")
        requireSmoke(restoredState.snapshotStatus == "Restored", "manual restore snapshot status mismatch")
    } finally {
        snapshotDir.toFile().deleteRecursively()
    }
}

private fun referenceAppReportsMissingManualQrWithoutPreview() {
    val snapshotDir = Files.createTempDirectory("grain-android-reference-empty-manual-snapshot")
    val snapshotPersistence = GrainFileSnapshotPersistence(snapshotDir.resolve("client-store.snapshot"))

    try {
        val configuration = GrainReferenceAppResources.bundled(
            snapshotPersistence = snapshotPersistence,
        )

        GrainReferenceScannerSession(configuration).use { session ->
            session.start()
            val controller = requireNotNull(session.controller) { "reference app did not create scanner controller" }

            session.loadManualScanAndPreview("  \n  ")

            requireSmoke(
                session.launchDiagnostic == ANDROID_REFERENCE_MANUAL_QR_MISSING_DIAG,
                "empty manual QR diagnostic mismatch",
            )
            requireSmoke(controller.state.previewStatus == null, "empty manual QR created preview")
            requireSmoke(!controller.state.canAccept, "empty manual QR enabled accept")
            requireSmoke(controller.state.acceptedCount == 0, "empty manual QR wrote accepted scan")
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
