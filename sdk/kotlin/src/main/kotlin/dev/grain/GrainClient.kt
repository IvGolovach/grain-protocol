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
import uniffi.grain_client_core.FfiStoreSnapshotResult
import uniffi.grain_client_core.FfiSyncBundleRequest
import uniffi.grain_client_core.FfiSyncResult
import uniffi.grain_client_core.GrainClientMemoryStore
import uniffi.grain_client_core.grainPairingPreviewEnvelope
import uniffi.grain_client_core.grainScanAcceptPrepare
import uniffi.grain_client_core.grainScanPreview

private const val SDK_ERR_TRUST_ANCHOR_REQUIRED = "SDK_ERR_TRUST_ANCHOR_REQUIRED"
private const val SDK_ERR_TRUST_ANCHOR_NOT_FOUND = "SDK_ERR_TRUST_ANCHOR_NOT_FOUND"

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

data class GrainStoreSnapshotResult(
    val status: String,
    val diag: List<String>,
    val snapshotB64: String?,
    val acceptedRecordCount: ULong,
    val deviceCount: ULong,
    val lifecycleEventCount: ULong,
)

fun interface GrainTrustProvider {
    fun trustPubB64(anchorId: String): String?
}

class GrainStaticTrustProvider(
    private val anchors: Map<String, String>,
) : GrainTrustProvider {
    constructor(anchorId: String, trustPubB64: String) : this(mapOf(anchorId to trustPubB64))

    override fun trustPubB64(anchorId: String): String? =
        anchors[anchorId]
}

class GrainClient : AutoCloseable {
    private val store = GrainClientMemoryStore()

    fun scanPreview(qrString: String, trustPubB64: String? = null): GrainScanPreview =
        grainScanPreview(FfiScanPreviewRequest(qrString = qrString, trustPubB64 = trustPubB64)).toPublic()

    fun scanPreview(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanPreview =
        when (val resolution = resolveTrustPubB64(trustAnchorId, trustProvider)) {
            is TrustResolution.Resolved -> scanPreview(qrString = qrString, trustPubB64 = resolution.trustPubB64)
            is TrustResolution.Rejected -> grainScanPreviewRejected(resolution.diag)
        }

    fun scanAcceptPrepare(qrString: String, trustPubB64: String): GrainScanAccept =
        grainScanAcceptPrepare(FfiScanAcceptRequest(qrString = qrString, trustPubB64 = trustPubB64)).toPublic()

    fun scanAcceptPrepare(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanAccept =
        when (val resolution = resolveTrustPubB64(trustAnchorId, trustProvider)) {
            is TrustResolution.Resolved -> scanAcceptPrepare(qrString = qrString, trustPubB64 = resolution.trustPubB64)
            is TrustResolution.Rejected -> grainScanAcceptRejected(resolution.diag)
        }

    fun scanAccept(qrString: String, trustPubB64: String): GrainScanAccept =
        store.scanAccept(FfiScanAcceptRequest(qrString = qrString, trustPubB64 = trustPubB64)).toPublic()

    fun scanAccept(
        qrString: String,
        trustAnchorId: String,
        trustProvider: GrainTrustProvider,
    ): GrainScanAccept =
        when (val resolution = resolveTrustPubB64(trustAnchorId, trustProvider)) {
            is TrustResolution.Resolved -> scanAccept(qrString = qrString, trustPubB64 = resolution.trustPubB64)
            is TrustResolution.Rejected -> grainScanAcceptRejected(resolution.diag)
        }

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

    fun exportStoreSnapshot(): GrainStoreSnapshotResult =
        store.exportStoreSnapshot().toPublic()

    fun restoreStoreSnapshot(snapshotB64: String): GrainStoreSnapshotResult =
        store.restoreStoreSnapshot(snapshotB64 = snapshotB64).toPublic()

    override fun close() {
        store.close()
    }
}

private sealed class TrustResolution {
    data class Resolved(val trustPubB64: String) : TrustResolution()
    data class Rejected(val diag: String) : TrustResolution()
}

private fun resolveTrustPubB64(anchorId: String, trustProvider: GrainTrustProvider): TrustResolution =
    when {
        anchorId.trim().isEmpty() -> TrustResolution.Rejected(SDK_ERR_TRUST_ANCHOR_REQUIRED)
        else -> trustProvider.trustPubB64(anchorId)?.let(TrustResolution::Resolved)
            ?: TrustResolution.Rejected(SDK_ERR_TRUST_ANCHOR_NOT_FOUND)
    }

private fun grainScanPreviewRejected(diag: String): GrainScanPreview =
    GrainScanPreview(
        status = GrainScanPreviewStatus.Rejected,
        diag = listOf(diag),
        coseB64 = null,
    )

private fun grainScanAcceptRejected(diag: String): GrainScanAccept =
    GrainScanAccept(
        status = GrainScanAcceptStatus.Rejected,
        diag = listOf(diag),
        scanId = null,
        coseB64 = null,
        trustPubB64 = null,
    )

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

private fun FfiStoreSnapshotResult.toPublic(): GrainStoreSnapshotResult =
    GrainStoreSnapshotResult(
        status = status,
        diag = diag,
        snapshotB64 = snapshotB64,
        acceptedRecordCount = acceptedRecordCount,
        deviceCount = deviceCount,
        lifecycleEventCount = lifecycleEventCount,
    )
