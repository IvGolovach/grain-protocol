package dev.grain.examples.androidreferenceapp

data class GrainAndroidReferenceAppState(
    val lifecycleStatus: String?,
    val acceptedCount: Int,
    val snapshotStatus: String?,
    val exportStatus: String?,
)

object GrainAndroidReferenceApp {
    fun runDemo(configuration: GrainReferenceAppConfiguration): GrainAndroidReferenceAppState {
        GrainReferenceScannerSession(configuration).use { session ->
            session.start()
            session.loadDemoScanAndPreview()
            session.acceptVerifiedPreview()
            session.exportAcceptedScansForShare()
            val state = requireNotNull(session.controller).state
            return GrainAndroidReferenceAppState(
                lifecycleStatus = state.lifecycleStatus,
                acceptedCount = state.acceptedCount,
                snapshotStatus = state.snapshotStatus,
                exportStatus = state.exportStatus,
            )
        }
    }
}
