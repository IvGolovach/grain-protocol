package dev.grain.android

import dev.grain.GrainClient
import dev.grain.GrainStoreSnapshotResult
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import javax.crypto.spec.SecretKeySpec

fun main() {
    fileSnapshotRoundTripAndClear()
    coordinatorPersistsRestoresAndClears()
    grainClientSnapshotBridgePersistsAndRestores()
    localSnapshotStoreSavesRestoresAndClears()
    keystoreBoundaryRoundTrip()
    aesGcmSnapshotCipherRoundTripAndTamperRejects()
    missingExportedSnapshotThrows()
    println("Kotlin Android adapters smoke: PASS")
}

private fun fileSnapshotRoundTripAndClear() {
    val dir = Files.createTempDirectory("grain-android-adapter-file")
    try {
        val persistence = GrainFileSnapshotPersistence(dir.resolve("client-store.snapshot"))
        requireSmoke(persistence.loadSnapshotB64() == null, "new file persistence was not empty")
        persistence.saveSnapshotB64("snapshot-one")
        requireSmoke(persistence.loadSnapshotB64() == "snapshot-one", "file snapshot round-trip mismatch")
        persistence.clearSnapshot()
        requireSmoke(persistence.loadSnapshotB64() == null, "file snapshot did not clear")
    } finally {
        dir.toFile().deleteRecursively()
    }
}

private fun coordinatorPersistsRestoresAndClears() {
    val persistence = RecordingSnapshotPersistence()
    val coordinator = GrainSnapshotCoordinator(persistence)
    val client = FakeSnapshotClient(exportResult = exportedSnapshot("snapshot-two"))

    val exported = coordinator.persist(client = client)
    requireSmoke(exported.status == "Exported", "coordinator export status mismatch")
    requireSmoke(persistence.savedSnapshotB64 == "snapshot-two", "coordinator did not persist snapshot")

    val restored = coordinator.restore(client = client)
    requireSmoke(restored?.status == "Restored", "coordinator restore status mismatch")
    requireSmoke(client.restoredSnapshotB64 == "snapshot-two", "coordinator restored wrong snapshot")

    client.exportResult = emptySnapshot()
    val empty = coordinator.persist(client = client)
    requireSmoke(empty.status == "Empty", "coordinator empty status mismatch")
    requireSmoke(persistence.savedSnapshotB64 == null, "coordinator did not clear empty snapshot")
}

private fun grainClientSnapshotBridgePersistsAndRestores() {
    val persistence = RecordingSnapshotPersistence()
    val coordinator = GrainSnapshotCoordinator(persistence)

    GrainClient().use { source ->
        requireSmoke(source.createRootIdentity(label = "phone").status == "Created", "bridge root create mismatch")
        requireSmoke(source.addDeviceKey(label = "scanner").status == "Added", "bridge device add mismatch")

        val exported = coordinator.persist(client = GrainClientSnapshotClient(source))
        requireSmoke(exported.status == "Exported", "bridge export status mismatch")
        requireSmoke(persistence.savedSnapshotB64 != null, "bridge did not persist snapshot")

        GrainClient().use { restoredClient ->
            val restored = coordinator.restore(client = GrainClientSnapshotClient(restoredClient))
            requireSmoke(restored?.status == "Restored", "bridge restore status mismatch")

            val lifecycle = restoredClient.clientLifecycle()
            requireSmoke(lifecycle.status == "Ready", "bridge lifecycle status mismatch")
            requireSmoke(lifecycle.deviceCount == 2UL, "bridge restored device count mismatch")
            requireSmoke(lifecycle.lifecycleEventCount == 1UL, "bridge restored lifecycle count mismatch")
        }
    }
}

private fun localSnapshotStoreSavesRestoresAndClears() {
    val persistence = RecordingSnapshotPersistence()
    val localStore = GrainLocalSnapshotStore(persistence)
    val client = FakeSnapshotClient(exportResult = exportedSnapshot("snapshot-local-store"))

    val saved = localStore.save(client = client)
    requireSmoke(saved.status == "Exported", "local store save status mismatch")
    requireSmoke(persistence.savedSnapshotB64 == "snapshot-local-store", "local store did not save snapshot")

    val restored = localStore.restore(client = client)
    requireSmoke(restored?.status == "Restored", "local store restore status mismatch")
    requireSmoke(client.restoredSnapshotB64 == "snapshot-local-store", "local store restored wrong snapshot")

    localStore.clear()
    requireSmoke(persistence.savedSnapshotB64 == null, "local store did not clear snapshot")
}

private fun keystoreBoundaryRoundTrip() {
    val bytes = RecordingByteSnapshotPersistence()
    val persistence = GrainKeystoreSnapshotPersistence(
        ciphertextPersistence = bytes,
        cipher = PrefixCipher(prefix = "sealed:"),
    )

    persistence.saveSnapshotB64("snapshot-three")
    requireSmoke(
        String(bytes.savedSnapshotBytes ?: ByteArray(0), StandardCharsets.UTF_8) == "sealed:snapshot-three",
        "keystore boundary did not seal snapshot",
    )
    requireSmoke(persistence.loadSnapshotB64() == "snapshot-three", "keystore boundary round-trip mismatch")
    persistence.clearSnapshot()
    requireSmoke(persistence.loadSnapshotB64() == null, "keystore boundary did not clear snapshot")
}

private fun aesGcmSnapshotCipherRoundTripAndTamperRejects() {
    val secretKey = SecretKeySpec(ByteArray(32) { index -> (index + 1).toByte() }, "AES")
    val cipher = GrainAesGcmSnapshotCipher(secretKey = secretKey)
    val snapshotB64 = "snapshot-four"

    val sealed = cipher.sealSnapshotB64(snapshotB64)

    requireSmoke(sealed.isNotEmpty(), "AES-GCM cipher returned empty ciphertext")
    requireSmoke(
        !sealed.contentEquals(snapshotB64.toByteArray(StandardCharsets.UTF_8)),
        "AES-GCM cipher did not seal snapshot bytes",
    )
    requireSmoke(cipher.openSnapshotB64(sealed) == snapshotB64, "AES-GCM cipher round-trip mismatch")

    val tampered = sealed.copyOf()
    tampered[tampered.lastIndex] = (tampered.last().toInt() xor 0x01).toByte()
    try {
        cipher.openSnapshotB64(tampered)
        error("tampered AES-GCM snapshot did not fail authentication")
    } catch (_: GrainSnapshotPersistenceException.CipherOpenFailed) {
        // Expected.
    }
}

private fun missingExportedSnapshotThrows() {
    val coordinator = GrainSnapshotCoordinator(RecordingSnapshotPersistence())
    val client = FakeSnapshotClient(
        exportResult = GrainStoreSnapshotResult(
            status = "Exported",
            diag = emptyList(),
            snapshotB64 = null,
            acceptedRecordCount = 0UL,
            deviceCount = 0UL,
            lifecycleEventCount = 0UL,
        ),
    )

    try {
        coordinator.persist(client = client)
        error("missing exported snapshot did not throw")
    } catch (_: GrainSnapshotPersistenceException.MissingExportedSnapshot) {
        // Expected.
    }
}

private class RecordingSnapshotPersistence : GrainSnapshotPersistence {
    var savedSnapshotB64: String? = null

    override fun loadSnapshotB64(): String? = savedSnapshotB64

    override fun saveSnapshotB64(snapshotB64: String) {
        savedSnapshotB64 = snapshotB64
    }

    override fun clearSnapshot() {
        savedSnapshotB64 = null
    }
}

private class RecordingByteSnapshotPersistence : GrainByteSnapshotPersistence {
    var savedSnapshotBytes: ByteArray? = null

    override fun loadSnapshotBytes(): ByteArray? = savedSnapshotBytes

    override fun saveSnapshotBytes(snapshotBytes: ByteArray) {
        savedSnapshotBytes = snapshotBytes
    }

    override fun clearSnapshot() {
        savedSnapshotBytes = null
    }
}

private class PrefixCipher(
    private val prefix: String,
) : GrainSnapshotCipher {
    override fun sealSnapshotB64(snapshotB64: String): ByteArray =
        "$prefix$snapshotB64".toByteArray(StandardCharsets.UTF_8)

    override fun openSnapshotB64(sealedSnapshot: ByteArray): String {
        val value = String(sealedSnapshot, StandardCharsets.UTF_8)
        require(value.startsWith(prefix)) { "invalid sealed snapshot prefix" }
        return value.removePrefix(prefix)
    }
}

private class FakeSnapshotClient(
    var exportResult: GrainStoreSnapshotResult,
) : GrainSnapshotClient {
    var restoredSnapshotB64: String? = null

    override fun exportStoreSnapshot(): GrainStoreSnapshotResult = exportResult

    override fun restoreStoreSnapshot(snapshotB64: String): GrainStoreSnapshotResult {
        restoredSnapshotB64 = snapshotB64
        return GrainStoreSnapshotResult(
            status = "Restored",
            diag = emptyList(),
            snapshotB64 = null,
            acceptedRecordCount = 1UL,
            deviceCount = 2UL,
            lifecycleEventCount = 3UL,
        )
    }
}

private fun exportedSnapshot(snapshotB64: String): GrainStoreSnapshotResult =
    GrainStoreSnapshotResult(
        status = "Exported",
        diag = emptyList(),
        snapshotB64 = snapshotB64,
        acceptedRecordCount = 1UL,
        deviceCount = 2UL,
        lifecycleEventCount = 3UL,
    )

private fun emptySnapshot(): GrainStoreSnapshotResult =
    GrainStoreSnapshotResult(
        status = "Empty",
        diag = emptyList(),
        snapshotB64 = null,
        acceptedRecordCount = 0UL,
        deviceCount = 0UL,
        lifecycleEventCount = 0UL,
    )

private fun requireSmoke(condition: Boolean, message: String) {
    if (!condition) {
        throw IllegalStateException(message)
    }
}
