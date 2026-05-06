package dev.grain.android

import dev.grain.GrainClient
import dev.grain.GrainStoreSnapshotResult
import java.security.GeneralSecurityException
import java.security.SecureRandom
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.nio.file.Path
import java.nio.file.StandardCopyOption.ATOMIC_MOVE
import java.nio.file.StandardCopyOption.REPLACE_EXISTING
import java.nio.file.StandardOpenOption.TRUNCATE_EXISTING
import java.nio.file.StandardOpenOption.WRITE
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface GrainSnapshotPersistence {
    fun loadSnapshotB64(): String?
    fun saveSnapshotB64(snapshotB64: String)
    fun clearSnapshot()
}

interface GrainSnapshotClient {
    fun exportStoreSnapshot(): GrainStoreSnapshotResult
    fun restoreStoreSnapshot(snapshotB64: String): GrainStoreSnapshotResult
}

class GrainClientSnapshotClient(
    private val client: GrainClient,
) : GrainSnapshotClient {
    override fun exportStoreSnapshot(): GrainStoreSnapshotResult =
        client.exportStoreSnapshot()

    override fun restoreStoreSnapshot(snapshotB64: String): GrainStoreSnapshotResult =
        client.restoreStoreSnapshot(snapshotB64 = snapshotB64)
}

class GrainSnapshotCoordinator(
    private val persistence: GrainSnapshotPersistence,
) {
    fun restore(client: GrainSnapshotClient): GrainStoreSnapshotResult? {
        val snapshotB64 = persistence.loadSnapshotB64() ?: return null
        return client.restoreStoreSnapshot(snapshotB64 = snapshotB64)
    }

    fun persist(client: GrainSnapshotClient): GrainStoreSnapshotResult {
        val result = client.exportStoreSnapshot()
        when (result.status) {
            "Exported" -> {
                val snapshotB64 = result.snapshotB64
                    ?: throw GrainSnapshotPersistenceException.MissingExportedSnapshot
                persistence.saveSnapshotB64(snapshotB64)
            }
            "Empty" -> persistence.clearSnapshot()
        }
        return result
    }
}

class GrainLocalSnapshotStore(
    private val persistence: GrainSnapshotPersistence,
) {
    private val coordinator = GrainSnapshotCoordinator(persistence)

    fun restore(client: GrainSnapshotClient): GrainStoreSnapshotResult? =
        coordinator.restore(client = client)

    fun save(client: GrainSnapshotClient): GrainStoreSnapshotResult =
        coordinator.persist(client = client)

    fun clear() {
        persistence.clearSnapshot()
    }
}

sealed class GrainSnapshotPersistenceException(message: String) : RuntimeException(message) {
    object MissingExportedSnapshot : GrainSnapshotPersistenceException(
        "exportStoreSnapshot returned Exported without snapshotB64",
    )
    object InvalidSealedSnapshot : GrainSnapshotPersistenceException(
        "sealed snapshot payload is not a Grain snapshot ciphertext",
    )
    object CipherOpenFailed : GrainSnapshotPersistenceException(
        "sealed snapshot payload could not be opened",
    )
}

interface GrainByteSnapshotPersistence {
    fun loadSnapshotBytes(): ByteArray?
    fun saveSnapshotBytes(snapshotBytes: ByteArray)
    fun clearSnapshot()
}

class GrainFileByteSnapshotPersistence(
    filePath: Path,
) : GrainByteSnapshotPersistence {
    private val filePath: Path = filePath.toAbsolutePath().normalize()

    override fun loadSnapshotBytes(): ByteArray? =
        try {
            Files.readAllBytes(filePath)
        } catch (_: NoSuchFileException) {
            null
        }

    override fun saveSnapshotBytes(snapshotBytes: ByteArray) {
        atomicWrite(filePath, snapshotBytes)
    }

    override fun clearSnapshot() {
        Files.deleteIfExists(filePath)
    }
}

class GrainFileSnapshotPersistence(
    filePath: Path,
) : GrainSnapshotPersistence {
    private val bytePersistence = GrainFileByteSnapshotPersistence(filePath)

    override fun loadSnapshotB64(): String? {
        val snapshotBytes = bytePersistence.loadSnapshotBytes() ?: return null
        val snapshotB64 = snapshotBytes.decodeUtf8Strict().trim()
        return snapshotB64.ifEmpty { null }
    }

    override fun saveSnapshotB64(snapshotB64: String) {
        bytePersistence.saveSnapshotBytes(snapshotB64.toByteArray(StandardCharsets.UTF_8))
    }

    override fun clearSnapshot() {
        bytePersistence.clearSnapshot()
    }
}

interface GrainSnapshotCipher {
    fun sealSnapshotB64(snapshotB64: String): ByteArray
    fun openSnapshotB64(sealedSnapshot: ByteArray): String
}

class GrainAesGcmSnapshotCipher(
    private val secretKey: SecretKey,
    associatedData: ByteArray = DEFAULT_ASSOCIATED_DATA,
    private val secureRandom: SecureRandom = SecureRandom(),
) : GrainSnapshotCipher {
    private val associatedData = associatedData.copyOf()

    override fun sealSnapshotB64(snapshotB64: String): ByteArray {
        val nonce = ByteArray(NONCE_BYTE_COUNT)
        secureRandom.nextBytes(nonce)
        val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey, GCMParameterSpec(GCM_TAG_BIT_COUNT, nonce))
        cipher.updateAAD(associatedData)
        val ciphertext = cipher.doFinal(snapshotB64.toByteArray(StandardCharsets.UTF_8))
        return GRAIN_SNAPSHOT_CIPHERTEXT_MAGIC + nonce + ciphertext
    }

    override fun openSnapshotB64(sealedSnapshot: ByteArray): String {
        if (
            sealedSnapshot.size <= GRAIN_SNAPSHOT_CIPHERTEXT_MAGIC.size + NONCE_BYTE_COUNT ||
            !sealedSnapshot.startsWith(GRAIN_SNAPSHOT_CIPHERTEXT_MAGIC)
        ) {
            throw GrainSnapshotPersistenceException.InvalidSealedSnapshot
        }

        val nonceStart = GRAIN_SNAPSHOT_CIPHERTEXT_MAGIC.size
        val ciphertextStart = nonceStart + NONCE_BYTE_COUNT
        val nonce = sealedSnapshot.copyOfRange(nonceStart, ciphertextStart)
        val ciphertext = sealedSnapshot.copyOfRange(ciphertextStart, sealedSnapshot.size)

        return try {
            val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(GCM_TAG_BIT_COUNT, nonce))
            cipher.updateAAD(associatedData)
            cipher.doFinal(ciphertext).decodeUtf8Strict()
        } catch (_: GeneralSecurityException) {
            throw GrainSnapshotPersistenceException.CipherOpenFailed
        }
    }

    companion object {
        private val DEFAULT_ASSOCIATED_DATA =
            "dev.grain.android.snapshot.v1".toByteArray(StandardCharsets.UTF_8)
        private val GRAIN_SNAPSHOT_CIPHERTEXT_MAGIC = byteArrayOf(0x47, 0x52, 0x53, 0x31)
        private const val AES_GCM_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val NONCE_BYTE_COUNT = 12
        private const val GCM_TAG_BIT_COUNT = 128
    }
}

class GrainKeystoreSnapshotPersistence(
    private val ciphertextPersistence: GrainByteSnapshotPersistence,
    private val cipher: GrainSnapshotCipher,
) : GrainSnapshotPersistence {
    override fun loadSnapshotB64(): String? {
        val sealedSnapshot = ciphertextPersistence.loadSnapshotBytes() ?: return null
        val snapshotB64 = cipher.openSnapshotB64(sealedSnapshot).trim()
        return snapshotB64.ifEmpty { null }
    }

    override fun saveSnapshotB64(snapshotB64: String) {
        ciphertextPersistence.saveSnapshotBytes(cipher.sealSnapshotB64(snapshotB64))
    }

    override fun clearSnapshot() {
        ciphertextPersistence.clearSnapshot()
    }
}

private fun ByteArray.startsWith(prefix: ByteArray): Boolean =
    size >= prefix.size && prefix.indices.all { this[it] == prefix[it] }

private fun ByteArray.decodeUtf8Strict(): String {
    val decoder = StandardCharsets.UTF_8
        .newDecoder()
        .onMalformedInput(CodingErrorAction.REPORT)
        .onUnmappableCharacter(CodingErrorAction.REPORT)
    return decoder.decode(ByteBuffer.wrap(this)).toString()
}

private fun atomicWrite(filePath: Path, bytes: ByteArray) {
    val target = filePath.toAbsolutePath().normalize()
    val parent = requireNotNull(target.parent) { "snapshot file must have a parent directory" }
    Files.createDirectories(parent)
    val tempFile = Files.createTempFile(parent, target.fileName.toString(), ".tmp")
    try {
        Files.write(tempFile, bytes, WRITE, TRUNCATE_EXISTING)
        try {
            Files.move(tempFile, target, ATOMIC_MOVE, REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(tempFile, target, REPLACE_EXISTING)
        }
    } finally {
        Files.deleteIfExists(tempFile)
    }
}
