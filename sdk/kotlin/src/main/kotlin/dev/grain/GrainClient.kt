package dev.grain

import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
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

import java.util.Base64

private const val SDK_ERR_TRUST_ANCHOR_REQUIRED = "SDK_ERR_TRUST_ANCHOR_REQUIRED"
private const val SDK_ERR_TRUST_ANCHOR_NOT_FOUND = "SDK_ERR_TRUST_ANCHOR_NOT_FOUND"
private const val SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID = "SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID"

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
) {
    override fun toString(): String =
        "GrainScanPreview(status=$status, diag=$diag, coseB64=${coseB64.redactedOptional()})"
}

data class GrainScanAccept(
    val status: GrainScanAcceptStatus,
    val diag: List<String>,
    val scanId: String?,
    val coseB64: String?,
    val trustPubB64: String?,
) {
    override fun toString(): String =
        "GrainScanAccept(status=$status, diag=$diag, scanId=$scanId, " +
            "coseB64=${coseB64.redactedOptional()}, trustPubB64=${trustPubB64.redactedOptional()})"
}

data class GrainAcceptedScan(
    val scanId: String,
    val coseB64: String,
    val trustPubB64: String,
) {
    override fun toString(): String =
        "GrainAcceptedScan(scanId=$scanId, coseB64=[REDACTED], trustPubB64=[REDACTED])"
}

enum class GrainScanHandoffSource(val rawValue: String) {
    ManualEntry("manual_entry"),
    Camera("camera"),
    Injected("injected"),
    ShareSheet("share_sheet"),
    DeepLink("deep_link"),
    Clipboard("clipboard"),
    RobotVision("robot_vision"),
    ExternalSensor("external_sensor"),
    Unknown("unknown");

    companion object {
        fun fromRawValue(rawValue: String): GrainScanHandoffSource? =
            values().firstOrNull { it.rawValue == rawValue }
    }
}

data class GrainScanHandoff(
    val qrString: String,
    val trustAnchorId: String?,
    val source: GrainScanHandoffSource = GrainScanHandoffSource.ManualEntry,
) {
    override fun toString(): String =
        "GrainScanHandoff(qrString=[REDACTED], trustAnchorId=$trustAnchorId, source=${source.rawValue})"
}

data class GrainIdentityResult(
    val status: String,
    val diag: List<String>,
    val rootKid: String?,
    val activeAk: String?,
    val bundleB64: String?,
    val deviceCount: ULong,
    val revokedCount: ULong,
    val lifecycleEventCount: ULong,
) {
    override fun toString(): String =
        "GrainIdentityResult(status=$status, diag=$diag, rootKid=$rootKid, activeAk=$activeAk, " +
            "bundleB64=${bundleB64.redactedOptional()}, deviceCount=$deviceCount, " +
            "revokedCount=$revokedCount, lifecycleEventCount=$lifecycleEventCount)"
}

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
) {
    override fun toString(): String =
        "GrainPairingResult(status=$status, diag=$diag, pairingId=$pairingId, " +
            "envelopeB64=${envelopeB64.redactedOptional()}, rootKid=$rootKid, deviceCount=$deviceCount)"
}

data class GrainSyncResult(
    val status: String,
    val diag: List<String>,
    val bundleB64: String?,
    val acceptedRecordCount: ULong,
    val deviceCount: ULong,
    val lifecycleEventCount: ULong,
) {
    override fun toString(): String =
        "GrainSyncResult(status=$status, diag=$diag, bundleB64=${bundleB64.redactedOptional()}, " +
            "acceptedRecordCount=$acceptedRecordCount, deviceCount=$deviceCount, " +
            "lifecycleEventCount=$lifecycleEventCount)"
}

data class GrainStoreSnapshotResult(
    val status: String,
    val diag: List<String>,
    val snapshotB64: String?,
    val acceptedRecordCount: ULong,
    val deviceCount: ULong,
    val lifecycleEventCount: ULong,
) {
    override fun toString(): String =
        "GrainStoreSnapshotResult(status=$status, diag=$diag, snapshotB64=${snapshotB64.redactedOptional()}, " +
            "acceptedRecordCount=$acceptedRecordCount, deviceCount=$deviceCount, " +
            "lifecycleEventCount=$lifecycleEventCount)"
}

enum class GrainCustodyMaterial {
    StoreSnapshot,
    IdentityBundle,
    PairingEnvelope,
    SyncBundle,
    TrustMaterial,
}

enum class GrainCustodyBinding {
    PortableTransfer,
    DeviceKeychain,
    DeviceKeystore,
    SecureEnclave,
    ExternalSecureModule,
    AppManaged,
}

data class GrainCustodyDescriptor(
    val material: GrainCustodyMaterial,
    val binding: GrainCustodyBinding,
    val exportable: Boolean,
    val deviceBound: Boolean,
)

object GrainCustodyPolicies {
    fun portableIdentityBundle(): GrainCustodyDescriptor =
        portable(GrainCustodyMaterial.IdentityBundle)

    fun portablePairingEnvelope(): GrainCustodyDescriptor =
        portable(GrainCustodyMaterial.PairingEnvelope)

    fun portableSyncBundle(): GrainCustodyDescriptor =
        portable(GrainCustodyMaterial.SyncBundle)

    fun deviceKeystoreSnapshot(): GrainCustodyDescriptor =
        GrainCustodyDescriptor(
            material = GrainCustodyMaterial.StoreSnapshot,
            binding = GrainCustodyBinding.DeviceKeystore,
            exportable = false,
            deviceBound = true,
        )

    private fun portable(material: GrainCustodyMaterial): GrainCustodyDescriptor =
        GrainCustodyDescriptor(
            material = material,
            binding = GrainCustodyBinding.PortableTransfer,
            exportable = true,
            deviceBound = false,
        )
}

fun interface GrainTrustProvider {
    fun trustPubB64(anchorId: String): String?
}

class GrainStaticTrustProvider(
    private val anchors: Map<String, String>,
) : GrainTrustProvider {
    constructor(anchorId: String, trustPubB64: String) : this(mapOf(anchorId to trustPubB64))
    constructor(bundleJson: String) : this(parseTrustAnchorBundleJson(bundleJson))

    override fun trustPubB64(anchorId: String): String? =
        anchors[anchorId]

    companion object {
        fun fromBundleJson(bundleJson: String): GrainStaticTrustProvider =
            GrainStaticTrustProvider(bundleJson)
    }
}

class GrainTrustAnchorBundleException :
    IllegalArgumentException(SDK_ERR_TRUST_ANCHOR_BUNDLE_INVALID)

private val trustAnchorBundleMapper = jacksonObjectMapper()

private fun parseTrustAnchorBundleJson(bundleJson: String): Map<String, String> {
    fun invalid(): Nothing = throw GrainTrustAnchorBundleException()

    val bundle = try {
        trustAnchorBundleMapper.readTree(bundleJson)
    } catch (_: Exception) {
        invalid()
    }
    if (!bundle.isObject || bundle.fieldNames().asSequence().toSet() != setOf("bundle_v", "anchors")) {
        invalid()
    }
    if (!bundle.get("bundle_v").isInt || bundle.get("bundle_v").asInt() != 1) {
        invalid()
    }
    val anchorsNode = bundle.get("anchors")
    if (!anchorsNode.isArray || anchorsNode.size() == 0) {
        invalid()
    }

    val anchors = linkedMapOf<String, String>()
    anchorsNode.forEach { anchor ->
        if (!anchor.isObject || anchor.fieldNames().asSequence().toSet() != setOf("id", "trust_pub_b64")) {
            invalid()
        }
        val idNode: JsonNode = anchor.get("id")
        val trustNode: JsonNode = anchor.get("trust_pub_b64")
        if (!idNode.isTextual || !trustNode.isTextual) {
            invalid()
        }
        val anchorId = idNode.asText()
        val trustPubB64 = trustNode.asText()
        if (
            anchorId.isEmpty() ||
            anchorId.trim() != anchorId ||
            anchors.containsKey(anchorId) ||
            !isNonEmptyStandardBase64(trustPubB64)
        ) {
            invalid()
        }
        anchors[anchorId] = trustPubB64
    }

    return anchors
}

private fun isNonEmptyStandardBase64(value: String): Boolean =
    try {
        Base64.getDecoder().decode(value).isNotEmpty()
    } catch (_: IllegalArgumentException) {
        false
    }

private fun String?.redactedOptional(): String =
    if (this == null) "null" else "[REDACTED]"

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

    fun scanPreview(
        handoff: GrainScanHandoff,
        trustProvider: GrainTrustProvider,
    ): GrainScanPreview =
        scanPreview(
            qrString = handoff.qrString,
            trustAnchorId = handoff.trustAnchorId ?: "",
            trustProvider = trustProvider,
        )

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

    fun scanAccept(
        handoff: GrainScanHandoff,
        trustProvider: GrainTrustProvider,
    ): GrainScanAccept =
        scanAccept(
            qrString = handoff.qrString,
            trustAnchorId = handoff.trustAnchorId ?: "",
            trustProvider = trustProvider,
        )

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
