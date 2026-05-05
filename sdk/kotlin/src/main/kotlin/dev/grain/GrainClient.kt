package dev.grain

import uniffi.grain_client_core.FfiAcceptedScan
import uniffi.grain_client_core.FfiScanAccept
import uniffi.grain_client_core.FfiScanAcceptRequest
import uniffi.grain_client_core.FfiScanPreview
import uniffi.grain_client_core.FfiScanPreviewRequest
import uniffi.grain_client_core.GrainClientMemoryStore
import uniffi.grain_client_core.grainScanAcceptPrepare
import uniffi.grain_client_core.grainScanPreview

sealed class GrainScanPreviewStatus(open val rawValue: String) {
    object Verified : GrainScanPreviewStatus("Verified")
    object Untrusted : GrainScanPreviewStatus("Untrusted")
    object Rejected : GrainScanPreviewStatus("Rejected")
    data class Unknown(override val rawValue: String) : GrainScanPreviewStatus(rawValue)

    companion object {
        fun from(rawValue: String): GrainScanPreviewStatus =
            when (rawValue) {
                Verified.rawValue -> Verified
                Untrusted.rawValue -> Untrusted
                Rejected.rawValue -> Rejected
                else -> Unknown(rawValue)
            }
    }
}

sealed class GrainScanAcceptStatus(open val rawValue: String) {
    object Accepted : GrainScanAcceptStatus("Accepted")
    object AlreadyAccepted : GrainScanAcceptStatus("AlreadyAccepted")
    object Rejected : GrainScanAcceptStatus("Rejected")
    data class Unknown(override val rawValue: String) : GrainScanAcceptStatus(rawValue)

    companion object {
        fun from(rawValue: String): GrainScanAcceptStatus =
            when (rawValue) {
                Accepted.rawValue -> Accepted
                AlreadyAccepted.rawValue -> AlreadyAccepted
                Rejected.rawValue -> Rejected
                else -> Unknown(rawValue)
            }
    }
}

data class GrainScanPreview(
    val status: GrainScanPreviewStatus,
    val diag: List<String>,
    val coseB64: String?,
)

data class GrainScanAccept(
    val status: GrainScanAcceptStatus,
    val diag: List<String>,
    val scanId: String?,
    val coseB64: String?,
    val trustPubB64: String?,
)

data class GrainAcceptedScan(
    val scanId: String,
    val coseB64: String,
    val trustPubB64: String,
)

class GrainClient : AutoCloseable {
    private val store = GrainClientMemoryStore()

    fun scanPreview(qrString: String, trustPubB64: String? = null): GrainScanPreview =
        grainScanPreview(FfiScanPreviewRequest(qrString = qrString, trustPubB64 = trustPubB64)).toPublic()

    fun scanAcceptPrepare(qrString: String, trustPubB64: String): GrainScanAccept =
        grainScanAcceptPrepare(FfiScanAcceptRequest(qrString = qrString, trustPubB64 = trustPubB64)).toPublic()

    fun scanAccept(qrString: String, trustPubB64: String): GrainScanAccept =
        store.scanAccept(FfiScanAcceptRequest(qrString = qrString, trustPubB64 = trustPubB64)).toPublic()

    fun listAcceptedScans(): List<GrainAcceptedScan> =
        store.listAcceptedScans().map { it.toPublic() }

    override fun close() {
        store.close()
    }
}

private fun FfiScanPreview.toPublic(): GrainScanPreview =
    GrainScanPreview(
        status = GrainScanPreviewStatus.from(status),
        diag = diag,
        coseB64 = coseB64,
    )

private fun FfiScanAccept.toPublic(): GrainScanAccept =
    GrainScanAccept(
        status = GrainScanAcceptStatus.from(status),
        diag = diag,
        scanId = scanId,
        coseB64 = coseB64,
        trustPubB64 = trustPubB64,
    )

private fun FfiAcceptedScan.toPublic(): GrainAcceptedScan =
    GrainAcceptedScan(
        scanId = scanId,
        coseB64 = coseB64,
        trustPubB64 = trustPubB64,
    )
