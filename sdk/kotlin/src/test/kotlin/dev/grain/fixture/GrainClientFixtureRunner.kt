package dev.grain.fixture

import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import dev.grain.GrainClient
import java.nio.file.Files
import java.nio.file.Path
import java.util.stream.Collectors
import kotlin.io.path.extension
import kotlin.io.path.name

fun main() {
    runScanPreviewFixtures()
    runScanAcceptFixtures()
    runDeviceLifecycleFixtures()
    runPairingFixtures()
    runSyncBundleFixtures()
    runStoreSnapshotFixtures()
    println("Kotlin client workflow fixtures: PASS")
}

private data class WorkflowFixture(
    @JsonProperty("fixture_id") val fixtureId: String,
    val workflow: String,
    val strict: Boolean,
    val input: FixtureInput,
    val expect: FixtureExpectation,
    val meta: Map<String, JsonNode>? = null,
)

private data class FixtureInput(
    @JsonProperty("qr_string_ref") val qrStringRef: String? = null,
    @JsonProperty("trust_pub_b64_ref") val trustPubB64Ref: String? = null,
    @JsonProperty("trust_pub_b64") val trustPubB64: String? = null,
    @JsonProperty("accept_attempts") val acceptAttempts: Int? = null,
    @JsonProperty("import_attempts") val importAttempts: Int? = null,
    @JsonProperty("root_label") val rootLabel: String? = null,
    @JsonProperty("device_label") val deviceLabel: String? = null,
)

private data class FixtureExpectation(
    val status: String,
    val diag: List<String>? = null,
    @JsonProperty("diag_contains") val diagContains: List<String>? = null,
    @JsonProperty("cose_b64") val coseB64: String? = null,
    @JsonProperty("store_mutation") val storeMutation: String? = null,
    @JsonProperty("accepted_record_count") val acceptedRecordCount: Int? = null,
    @JsonProperty("device_count") val deviceCount: Long? = null,
    @JsonProperty("revoked_count") val revokedCount: Long? = null,
    @JsonProperty("lifecycle_event_count") val lifecycleEventCount: Long? = null,
    @JsonProperty("root_kid") val rootKid: String? = null,
    @JsonProperty("active_ak") val activeAk: String? = null,
    @JsonProperty("device_ak") val deviceAk: String? = null,
    @JsonProperty("pairing_id") val pairingId: String? = null,
    @JsonProperty("envelope_b64") val envelopeB64: String? = null,
    @JsonProperty("bundle_b64") val bundleB64: String? = null,
    @JsonProperty("snapshot_b64") val snapshotB64: String? = null,
)

private val mapper = jacksonObjectMapper()

private fun runScanPreviewFixtures() {
    loadFixtures("scan-preview").forEach { fixture ->
        requireFixture(fixture.workflow == "scan_preview", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        val qrString = fixtureQrString(fixture)
        val trustPubB64 = resolveTrustInput(fixture.input)

        GrainClient().use { client ->
            val preview = client.scanPreview(qrString = qrString, trustPubB64 = trustPubB64)
            requireFixture(preview.status.rawValue == fixture.expect.status, "${fixture.fixtureId} status mismatch")
            requireDiagnostics(preview.diag, fixture.expect, fixture.fixtureId)
            requireCosePresence(
                preview.coseB64,
                requiredExpectation(fixture.expect.coseB64, "cose_b64", fixture.fixtureId),
                fixture.fixtureId,
            )
            requireFixture(client.listAcceptedScans().isEmpty(), "${fixture.fixtureId} preview mutated storage")
        }
    }
}

private fun runScanAcceptFixtures() {
    loadFixtures("scan-accept").forEach { fixture ->
        requireFixture(fixture.workflow == "scan_accept", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        val qrString = fixtureQrString(fixture)
        val trustPubB64 = resolveTrustInput(fixture.input)
            ?: throw FixtureException("${fixture.fixtureId} missing trust material")

        val attempts = fixture.input.acceptAttempts ?: 1
        requireFixture(attempts > 0, "${fixture.fixtureId} accept_attempts must be positive")

        GrainClient().use { client ->
            var acceptedStatus: String? = null
            var acceptedDiag: List<String>? = null
            var acceptedCoseB64: String? = null

            repeat(attempts) {
                val accepted = client.scanAccept(qrString = qrString, trustPubB64 = trustPubB64)
                acceptedStatus = accepted.status.rawValue
                acceptedDiag = accepted.diag
                acceptedCoseB64 = accepted.coseB64
            }

            requireFixture(acceptedStatus == fixture.expect.status, "${fixture.fixtureId} status mismatch")
            requireDiagnostics(acceptedDiag ?: emptyList(), fixture.expect, fixture.fixtureId)
            requireCosePresence(
                acceptedCoseB64,
                requiredExpectation(fixture.expect.coseB64, "cose_b64", fixture.fixtureId),
                fixture.fixtureId,
            )

            val records = client.listAcceptedScans()
            when (requiredExpectation(fixture.expect.storeMutation, "store_mutation", fixture.fixtureId)) {
                "accepted_scan_inserted" ->
                    requireFixture(records.isNotEmpty(), "${fixture.fixtureId} expected persisted record")
                "none" ->
                    requireFixture(records.isEmpty(), "${fixture.fixtureId} expected no persisted records")
                else -> throw FixtureException("${fixture.fixtureId} unsupported store mutation")
            }

            fixture.expect.acceptedRecordCount?.let { expectedCount ->
                requireFixture(records.size == expectedCount, "${fixture.fixtureId} accepted record count mismatch")
            }
        }
    }
}

private fun runDeviceLifecycleFixtures() {
    loadFixtures("device-lifecycle").forEach { fixture ->
        requireFixture(fixture.workflow == "device_lifecycle", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        GrainClient().use { client ->
            val root = client.createRootIdentity(label = fixture.input.rootLabel ?: "root")
            requireFixture(root.status == "Created", "${fixture.fixtureId} root create mismatch")

            val added = client.addDeviceKey(label = fixture.input.deviceLabel ?: "device")
            requireFixture(added.status == "Added", "${fixture.fixtureId} device add mismatch")
            val deviceAk = added.deviceAk ?: throw FixtureException("${fixture.fixtureId} missing device ak")

            val active = client.setActiveDevice(ak = deviceAk)
            requireFixture(active.status == "Active", "${fixture.fixtureId} active device mismatch")
            val revoked = client.revokeDeviceKey(ak = deviceAk)
            requireFixture(revoked.status == "Revoked", "${fixture.fixtureId} revoke mismatch")

            val lifecycle = client.clientLifecycle()
            requireFixture(lifecycle.status == fixture.expect.status, "${fixture.fixtureId} lifecycle status mismatch")
            requireDiagnostics(lifecycle.diag, fixture.expect, fixture.fixtureId)
            requirePresence(lifecycle.rootKid, fixture.expect.rootKid, "root_kid", fixture.fixtureId)
            requirePresence(lifecycle.activeAk, fixture.expect.activeAk, "active_ak", fixture.fixtureId)
            requirePresence(deviceAk, fixture.expect.deviceAk, "device_ak", fixture.fixtureId)
            requireCount(lifecycle.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureId)
            requireCount(lifecycle.revokedCount, fixture.expect.revokedCount, "revoked_count", fixture.fixtureId)
            fixture.expect.acceptedRecordCount?.let { expectedCount ->
                requireFixture(
                    lifecycle.acceptedRecordCount.toLong() == expectedCount.toLong(),
                    "${fixture.fixtureId} accepted_record_count mismatch",
                )
            }
            requireCount(
                lifecycle.lifecycleEventCount,
                fixture.expect.lifecycleEventCount,
                "lifecycle_event_count",
                fixture.fixtureId,
            )
        }
    }
}

private fun runPairingFixtures() {
    loadFixtures("pairing").forEach { fixture ->
        requireFixture(fixture.workflow == "pairing", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        GrainClient().use { source ->
            requireFixture(
                source.createRootIdentity(label = fixture.input.rootLabel ?: "root").status == "Created",
                "${fixture.fixtureId} root create mismatch",
            )
            requireFixture(
                source.addDeviceKey(label = fixture.input.deviceLabel ?: "device").status == "Added",
                "${fixture.fixtureId} device add mismatch",
            )

            val envelope = source.createPairingEnvelope()
            requireFixture(envelope.status == "Created", "${fixture.fixtureId} envelope create mismatch")
            requirePresence(envelope.envelopeB64, fixture.expect.envelopeB64, "envelope_b64", fixture.fixtureId)
            val envelopeB64 = envelope.envelopeB64 ?: throw FixtureException("${fixture.fixtureId} missing envelope")
            val preview = source.previewPairingEnvelope(envelopeB64 = envelopeB64)
            requireFixture(preview.status == "Valid", "${fixture.fixtureId} pairing preview mismatch")

            GrainClient().use { target ->
                val attempts = fixture.input.acceptAttempts ?: 1
                requireFixture(attempts > 0, "${fixture.fixtureId} accept_attempts must be positive")
                var paired: dev.grain.GrainPairingResult? = null
                repeat(attempts) {
                    paired = target.acceptPairingEnvelope(envelopeB64 = envelopeB64)
                }
                val result = paired ?: throw FixtureException("${fixture.fixtureId} did not execute pairing accept")
                requireFixture(result.status == fixture.expect.status, "${fixture.fixtureId} pairing status mismatch")
                requireDiagnostics(result.diag, fixture.expect, fixture.fixtureId)
                requirePresence(result.rootKid, fixture.expect.rootKid, "root_kid", fixture.fixtureId)
                requirePresence(result.pairingId, fixture.expect.pairingId, "pairing_id", fixture.fixtureId)
                requireCount(result.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureId)
            }
        }
    }
}

private fun runSyncBundleFixtures() {
    loadFixtures("sync-bundle").forEach { fixture ->
        requireFixture(fixture.workflow == "sync_bundle", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        GrainClient().use { source ->
            requireFixture(
                source.createRootIdentity(label = fixture.input.rootLabel ?: "root").status == "Created",
                "${fixture.fixtureId} root create mismatch",
            )
            requireFixture(
                source.addDeviceKey(label = fixture.input.deviceLabel ?: "device").status == "Added",
                "${fixture.fixtureId} device add mismatch",
            )
            val trustPubB64 = resolveTrustInput(fixture.input)
                ?: throw FixtureException("${fixture.fixtureId} missing trust material")
            val accepted = source.scanAccept(qrString = fixtureQrString(fixture), trustPubB64 = trustPubB64)
            requireFixture(accepted.status.rawValue == "Accepted", "${fixture.fixtureId} scan accept mismatch")

            val exported = source.exportSyncBundle()
            requireFixture(exported.status == "Exported", "${fixture.fixtureId} sync export mismatch")
            requirePresence(exported.bundleB64, fixture.expect.bundleB64, "bundle_b64", fixture.fixtureId)
            val bundleB64 = exported.bundleB64 ?: throw FixtureException("${fixture.fixtureId} missing sync bundle")

            GrainClient().use { target ->
                val attempts = fixture.input.importAttempts ?: 1
                requireFixture(attempts > 0, "${fixture.fixtureId} import_attempts must be positive")
                var imported: dev.grain.GrainSyncResult? = null
                repeat(attempts) {
                    imported = target.importSyncBundle(bundleB64 = bundleB64)
                }
                val result = imported ?: throw FixtureException("${fixture.fixtureId} did not execute sync import")
                requireFixture(result.status == fixture.expect.status, "${fixture.fixtureId} sync status mismatch")
                requireDiagnostics(result.diag, fixture.expect, fixture.fixtureId)
                fixture.expect.acceptedRecordCount?.let { expectedCount ->
                    requireFixture(
                        result.acceptedRecordCount.toLong() == expectedCount.toLong(),
                        "${fixture.fixtureId} accepted_record_count mismatch",
                    )
                }
                requireCount(result.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureId)
                requireCount(
                    result.lifecycleEventCount,
                    fixture.expect.lifecycleEventCount,
                    "lifecycle_event_count",
                    fixture.fixtureId,
                )
            }
        }
    }
}

private fun runStoreSnapshotFixtures() {
    GrainClient().use { empty ->
        val snapshot = empty.exportStoreSnapshot()
        requireFixture(snapshot.status == "Empty", "store snapshot empty status mismatch")
        requireFixture(snapshot.snapshotB64 == null, "empty store snapshot must not produce payload")
    }

    loadFixtures("store-snapshot").forEach { fixture ->
        requireFixture(fixture.workflow == "store_snapshot", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        GrainClient().use { source ->
            GrainClient().use { target ->
                requireFixture(
                    source.createRootIdentity(label = fixture.input.rootLabel ?: "root").status == "Created",
                    "${fixture.fixtureId} root create mismatch",
                )
                requireFixture(
                    source.addDeviceKey(label = fixture.input.deviceLabel ?: "device").status == "Added",
                    "${fixture.fixtureId} device add mismatch",
                )
                val trustPubB64 = resolveTrustInput(fixture.input)
                    ?: throw FixtureException("${fixture.fixtureId} missing trust material")
                val accepted = source.scanAccept(
                    qrString = fixtureQrString(fixture),
                    trustPubB64 = trustPubB64,
                )
                requireFixture(accepted.status.rawValue == "Accepted", "${fixture.fixtureId} scan accept mismatch")

                val exported = source.exportStoreSnapshot()
                requireFixture(exported.status == "Exported", "${fixture.fixtureId} snapshot export mismatch")
                requirePresence(exported.snapshotB64, fixture.expect.snapshotB64, "snapshot_b64", fixture.fixtureId)

                val snapshotB64 = exported.snapshotB64
                    ?: throw FixtureException("${fixture.fixtureId} missing snapshot_b64")
                val restored = target.restoreStoreSnapshot(snapshotB64 = snapshotB64)
                requireFixture(restored.status == fixture.expect.status, "${fixture.fixtureId} snapshot restore mismatch")
                requireDiagnostics(restored.diag, fixture.expect, fixture.fixtureId)
                requireCount(
                    restored.acceptedRecordCount,
                    fixture.expect.acceptedRecordCount?.toLong(),
                    "accepted_record_count",
                    fixture.fixtureId,
                )
                requireCount(restored.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureId)
                requireCount(
                    restored.lifecycleEventCount,
                    fixture.expect.lifecycleEventCount,
                    "lifecycle_event_count",
                    fixture.fixtureId,
                )

                val lifecycle = target.clientLifecycle()
                requireFixture(lifecycle.status == "Ready", "${fixture.fixtureId} lifecycle status mismatch")
                requireCount(
                    lifecycle.acceptedRecordCount,
                    fixture.expect.acceptedRecordCount?.toLong(),
                    "accepted_record_count",
                    fixture.fixtureId,
                )
                requireCount(lifecycle.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureId)
                requireCount(
                    lifecycle.lifecycleEventCount,
                    fixture.expect.lifecycleEventCount,
                    "lifecycle_event_count",
                    fixture.fixtureId,
                )
            }
        }
    }
}

private fun loadFixtures(kind: String): List<WorkflowFixture> {
    val directory = repoRoot().resolve("sdk/workflows/fixtures/$kind")
    val urls = Files.list(directory).use { paths ->
        paths
            .filter { it.extension == "json" }
            .sorted { left, right -> left.name.compareTo(right.name) }
            .collect(Collectors.toList())
    }
    requireFixture(urls.isNotEmpty(), "$kind fixture set is empty")
    return urls.map { mapper.readValue(it.toFile()) }
}

private fun resolveTrustInput(input: FixtureInput): String? =
    when {
        input.trustPubB64Ref != null && input.trustPubB64 == null -> resolveStringRef(input.trustPubB64Ref)
        input.trustPubB64Ref == null && input.trustPubB64 != null -> input.trustPubB64
        input.trustPubB64Ref == null && input.trustPubB64 == null -> null
        else -> throw FixtureException("trust_pub_b64_ref and trust_pub_b64 are mutually exclusive")
    }

private fun fixtureQrString(fixture: WorkflowFixture): String =
    resolveStringRef(
        fixture.input.qrStringRef
            ?: throw FixtureException("${fixture.fixtureId} missing qr_string_ref"),
    )

private fun <T> requiredExpectation(value: T?, field: String, fixtureId: String): T =
    value ?: throw FixtureException("$fixtureId missing $field expectation")

private fun resolveStringRef(ref: String): String {
    val parts = ref.split("#", limit = 2)
    if (parts.size != 2 || !parts[1].startsWith("/")) {
        throw FixtureException("invalid ref: $ref")
    }

    val relativePath = parts[0]
    val components = relativePath.split("/")
    if (
        relativePath.isEmpty() ||
        relativePath.startsWith("/") ||
        !relativePath.startsWith("conformance/vectors/") ||
        components.any { it.isEmpty() || it == "." || it == ".." }
    ) {
        throw FixtureException("invalid ref: $ref")
    }

    val root = repoRoot()
    val vectorsRoot = root.resolve("conformance/vectors").normalize()
    val file = root.resolve(relativePath).normalize()
    if (!file.startsWith(vectorsRoot)) {
        throw FixtureException("invalid ref: $ref")
    }

    var node: JsonNode = mapper.readTree(file.toFile())
    parts[1].drop(1).split("/").forEach { rawToken ->
        val token = decodeJsonPointerToken(rawToken)
        node = when {
            node.isObject -> node.get(token) ?: throw FixtureException("invalid ref: $ref")
            node.isArray -> node.get(token.toIntOrNull() ?: -1) ?: throw FixtureException("invalid ref: $ref")
            else -> throw FixtureException("invalid ref: $ref")
        }
    }

    if (!node.isTextual) {
        throw FixtureException("invalid ref: $ref")
    }
    return node.asText()
}

private fun decodeJsonPointerToken(token: String): String =
    token.replace("~1", "/").replace("~0", "~")

private fun repoRoot(): Path {
    val configured = System.getProperty("grain.repoRoot")
        ?: throw FixtureException("grain.repoRoot system property is required")
    return Path.of(configured).toAbsolutePath().normalize()
}

private fun requireDiagnostics(actual: List<String>, expectation: FixtureExpectation, fixtureId: String) {
    expectation.diag?.let { expected ->
        requireFixture(actual == expected, "$fixtureId exact diagnostics mismatch")
    }

    expectation.diagContains?.let { expectedContains ->
        requireFixture(expectedContains.isNotEmpty(), "$fixtureId diag_contains must not be empty")
        expectedContains.forEach { code ->
            requireFixture(actual.contains(code), "$fixtureId expected diagnostic $code, actual $actual")
        }
    }
}

private fun requireCosePresence(coseB64: String?, expectation: String, fixtureId: String) {
    when (expectation) {
        "present" -> requireFixture(coseB64 != null, "$fixtureId expected COSE")
        "absent" -> requireFixture(coseB64 == null, "$fixtureId expected no COSE")
        else -> throw FixtureException("$fixtureId unsupported cose_b64 expectation")
    }
}

private fun requirePresence(actual: String?, expectation: String?, field: String, fixtureId: String) {
    when (expectation) {
        "present" -> requireFixture(!actual.isNullOrEmpty(), "$fixtureId expected $field")
        "absent" -> requireFixture(actual == null, "$fixtureId expected no $field")
        null -> return
        else -> throw FixtureException("$fixtureId unsupported $field expectation")
    }
}

private fun requireCount(actual: ULong, expectation: Long?, field: String, fixtureId: String) {
    expectation?.let { expected ->
        requireFixture(actual.toLong() == expected, "$fixtureId $field mismatch")
    }
}

private fun requireFixture(condition: Boolean, message: String) {
    if (!condition) {
        throw FixtureException(message)
    }
}

private class FixtureException(message: String) : RuntimeException(message)
