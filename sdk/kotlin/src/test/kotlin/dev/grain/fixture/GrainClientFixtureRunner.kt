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
    @JsonProperty("qr_string_ref") val qrStringRef: String,
    @JsonProperty("trust_pub_b64_ref") val trustPubB64Ref: String? = null,
    @JsonProperty("trust_pub_b64") val trustPubB64: String? = null,
    @JsonProperty("accept_attempts") val acceptAttempts: Int? = null,
)

private data class FixtureExpectation(
    val status: String,
    val diag: List<String>? = null,
    @JsonProperty("diag_contains") val diagContains: List<String>? = null,
    @JsonProperty("cose_b64") val coseB64: String,
    @JsonProperty("store_mutation") val storeMutation: String,
    @JsonProperty("accepted_record_count") val acceptedRecordCount: Int? = null,
)

private val mapper = jacksonObjectMapper()

private fun runScanPreviewFixtures() {
    loadFixtures("scan-preview").forEach { fixture ->
        requireFixture(fixture.workflow == "scan_preview", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        val qrString = resolveStringRef(fixture.input.qrStringRef)
        val trustPubB64 = resolveTrustInput(fixture.input)

        GrainClient().use { client ->
            val preview = client.scanPreview(qrString = qrString, trustPubB64 = trustPubB64)
            requireFixture(preview.status.rawValue == fixture.expect.status, "${fixture.fixtureId} status mismatch")
            requireDiagnostics(preview.diag, fixture.expect, fixture.fixtureId)
            requireCosePresence(preview.coseB64, fixture.expect.coseB64, fixture.fixtureId)
            requireFixture(client.listAcceptedScans().isEmpty(), "${fixture.fixtureId} preview mutated storage")
        }
    }
}

private fun runScanAcceptFixtures() {
    loadFixtures("scan-accept").forEach { fixture ->
        requireFixture(fixture.workflow == "scan_accept", "${fixture.fixtureId} workflow mismatch")
        requireFixture(fixture.strict, "${fixture.fixtureId} must be strict")

        val qrString = resolveStringRef(fixture.input.qrStringRef)
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
            requireCosePresence(acceptedCoseB64, fixture.expect.coseB64, fixture.fixtureId)

            val records = client.listAcceptedScans()
            when (fixture.expect.storeMutation) {
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

private fun requireFixture(condition: Boolean, message: String) {
    if (!condition) {
        throw FixtureException(message)
    }
}

private class FixtureException(message: String) : RuntimeException(message)
