package dev.grain.examples.androidreferenceapp

import dev.grain.GrainSyncResult

data class GrainAndroidReferenceExportSummary(
    val status: String,
    val acceptedRecordCount: ULong,
    val deviceCount: ULong,
    val lifecycleEventCount: ULong,
    val diagnostics: List<String>,
) {
    companion object {
        fun fromSyncResult(result: GrainSyncResult): GrainAndroidReferenceExportSummary =
            GrainAndroidReferenceExportSummary(
                status = result.status,
                acceptedRecordCount = result.acceptedRecordCount,
                deviceCount = result.deviceCount,
                lifecycleEventCount = result.lifecycleEventCount,
                diagnostics = result.diag,
            )
    }
}

data class GrainAndroidReferenceAppState(
    val launchDiagnostic: String?,
    val lifecycleStatus: String?,
    val deviceCount: ULong,
    val lifecycleEventCount: ULong,
    val previewStatus: String?,
    val acceptStatus: String?,
    val scanSource: String?,
    val canAccept: Boolean,
    val acceptedCount: Int,
    val acceptedScanIds: List<String>,
    val acceptedScanId: String?,
    val snapshotStatus: String?,
    val exportSummary: GrainAndroidReferenceExportSummary?,
    val diagnostics: List<String>,
)

object GrainAndroidReferenceApp {
    fun runDemo(configuration: GrainReferenceAppConfiguration): GrainAndroidReferenceAppState {
        return runPreviewAcceptExport(configuration) { session ->
            session.loadDemoScanAndPreview()
        }
    }

    fun runManual(
        configuration: GrainReferenceAppConfiguration,
        qrString: String,
    ): GrainAndroidReferenceAppState {
        return runPreviewAcceptExport(configuration) { session ->
            session.loadManualScanAndPreview(qrString)
        }
    }

    fun restore(configuration: GrainReferenceAppConfiguration): GrainAndroidReferenceAppState {
        GrainReferenceScannerSession(configuration).use { session ->
            session.start()
            return session.toAppState()
        }
    }

    private fun runPreviewAcceptExport(
        configuration: GrainReferenceAppConfiguration,
        loadAndPreview: (GrainReferenceScannerSession) -> Unit,
    ): GrainAndroidReferenceAppState {
        GrainReferenceScannerSession(configuration).use { session ->
            session.start()
            loadAndPreview(session)
            session.acceptVerifiedPreview()
            val exportSummary = session.exportAcceptedScansForShare()
            return session.toAppState(exportSummary)
        }
    }
}

private fun GrainReferenceScannerSession.toAppState(
    exportSummary: GrainAndroidReferenceExportSummary? = null,
): GrainAndroidReferenceAppState {
    val scannerState = controller?.state
    return GrainAndroidReferenceAppState(
        launchDiagnostic = launchDiagnostic,
        lifecycleStatus = scannerState?.lifecycleStatus,
        deviceCount = scannerState?.deviceCount ?: 0UL,
        lifecycleEventCount = scannerState?.lifecycleEventCount ?: 0UL,
        previewStatus = scannerState?.previewStatus?.rawValue,
        acceptStatus = scannerState?.acceptStatus?.rawValue,
        scanSource = scannerState?.scanSource?.name,
        canAccept = scannerState?.canAccept ?: false,
        acceptedCount = scannerState?.acceptedCount ?: 0,
        acceptedScanIds = scannerState?.acceptedScans?.map { it.scanId }.orEmpty(),
        acceptedScanId = scannerState?.acceptedScanId,
        snapshotStatus = scannerState?.snapshotStatus,
        exportSummary = exportSummary,
        diagnostics = scannerState?.diagnostics.orEmpty(),
    )
}
