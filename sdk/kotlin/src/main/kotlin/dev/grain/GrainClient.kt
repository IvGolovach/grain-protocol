package dev.grain

import uniffi.grain_client_core.FfiAcceptedScan
import uniffi.grain_client_core.FfiClientLifecycle
import uniffi.grain_client_core.FfiDeviceResult
import uniffi.grain_client_core.FfiIdentityResult
import uniffi.grain_client_core.FfiPairingEnvelopeRequest
import uniffi.grain_client_core.FfiPairingResult
import uniffi.grain_client_core.FfiScanAccept
import uniffi.grain_client_core.FfiScanAcceptRequest
import uniffi.grain_client_core.FfiScanPreview
import uniffi.grain_client_core.FfiScanPreviewRequest
import uniffi.grain_client_core.FfiSyncBundleRequest
import uniffi.grain_client_core.FfiSyncResult
import uniffi.grain_client_core.GrainClientMemoryStore
import uniffi.grain_client_core.grainPairingPreviewEnvelope
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

data class GrainIdentityResult(
    val status: String,
    val diag: List<String>,
    val rootKid: String?,
    val activeAk: String?,
    val bundleB64: String?,
    val deviceCount: ULong,
    val revokedCount: ULong,
    val lifecycleEventCount: ULong,
)

data class GrainDeviceResult(
    val status: String,
    val diag: List<String>,
    val deviceAk: String?,
    val activeAk: String?,
    val rootKid: String?,
    val deviceCount: ULong,
    val revokedCount: ULong,
    val lifecycleEventCount: ULong,
)

data class GrainClientLifecycle(
    val status: String,
    val diag: List<String>,
    val rootKid: String?,
    val activeAk: String?,
    val deviceCount: ULong,
    val revokedCount: ULong,
    val acceptedRecordCount: ULong,
    val lifecycleEventCount: ULong,
)

data class GrainPairingResult(
    val status: String,
    val diag: List<String>,
    val pairingId: String?,
    val envelopeB64: String?,
    val rootKid: String?,
    val deviceCount: ULong,
)

data class GrainSyncResult(
    val status: String,
    val diag: List<String>,
    val bundleB64: String?,
    val acceptedRecordCount: ULong,
    val deviceCount: ULong,
    val lifecycleEventCount: ULong,
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

    fun createRootIdentity(label: String = "root"): GrainIdentityResult =
        store.createRootIdentity(label = label).toPublic()

    fun exportIdentityBundle(): GrainIdentityResult =
        store.exportIdentityBundle().toPublic()

    fun importIdentityBundle(bundleB64: String): GrainIdentityResult =
        store.importIdentityBundle(bundleB64 = bundleB64).toPublic()

    fun addDeviceKey(label: String = "device"): GrainDeviceResult =
        store.addDeviceKey(label = label).toPublic()

    fun revokeDeviceKey(ak: String): GrainDeviceResult =
        store.revokeDeviceKey(ak = ak).toPublic()

    fun setActiveDevice(ak: String): GrainDeviceResult =
        store.setActiveDevice(ak = ak).toPublic()

    fun clientLifecycle(): GrainClientLifecycle =
        store.clientLifecycle().toPublic()

    fun createPairingEnvelope(): GrainPairingResult =
        store.createPairingEnvelope().toPublic()

    fun previewPairingEnvelope(envelopeB64: String): GrainPairingResult =
        grainPairingPreviewEnvelope(FfiPairingEnvelopeRequest(envelopeB64 = envelopeB64)).toPublic()

    fun acceptPairingEnvelope(envelopeB64: String): GrainPairingResult =
        store.acceptPairingEnvelope(FfiPairingEnvelopeRequest(envelopeB64 = envelopeB64)).toPublic()

    fun exportSyncBundle(): GrainSyncResult =
        store.exportSyncBundle().toPublic()

    fun importSyncBundle(bundleB64: String): GrainSyncResult =
        store.importSyncBundle(FfiSyncBundleRequest(bundleB64 = bundleB64)).toPublic()

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

private fun FfiIdentityResult.toPublic(): GrainIdentityResult =
    GrainIdentityResult(
        status = status,
        diag = diag,
        rootKid = rootKid,
        activeAk = activeAk,
        bundleB64 = bundleB64,
        deviceCount = deviceCount,
        revokedCount = revokedCount,
        lifecycleEventCount = lifecycleEventCount,
    )

private fun FfiDeviceResult.toPublic(): GrainDeviceResult =
    GrainDeviceResult(
        status = status,
        diag = diag,
        deviceAk = deviceAk,
        activeAk = activeAk,
        rootKid = rootKid,
        deviceCount = deviceCount,
        revokedCount = revokedCount,
        lifecycleEventCount = lifecycleEventCount,
    )

private fun FfiClientLifecycle.toPublic(): GrainClientLifecycle =
    GrainClientLifecycle(
        status = status,
        diag = diag,
        rootKid = rootKid,
        activeAk = activeAk,
        deviceCount = deviceCount,
        revokedCount = revokedCount,
        acceptedRecordCount = acceptedRecordCount,
        lifecycleEventCount = lifecycleEventCount,
    )

private fun FfiPairingResult.toPublic(): GrainPairingResult =
    GrainPairingResult(
        status = status,
        diag = diag,
        pairingId = pairingId,
        envelopeB64 = envelopeB64,
        rootKid = rootKid,
        deviceCount = deviceCount,
    )

private fun FfiSyncResult.toPublic(): GrainSyncResult =
    GrainSyncResult(
        status = status,
        diag = diag,
        bundleB64 = bundleB64,
        acceptedRecordCount = acceptedRecordCount,
        deviceCount = deviceCount,
        lifecycleEventCount = lifecycleEventCount,
    )
