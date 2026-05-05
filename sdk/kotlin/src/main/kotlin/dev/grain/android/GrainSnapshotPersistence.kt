package dev.grain.android

import dev.grain.GrainClient
import dev.grain.GrainStoreSnapshotResult
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

sealed class GrainSnapshotPersistenceException(message: String) : RuntimeException(message) {
    object MissingExportedSnapshot : GrainSnapshotPersistenceException(
        "exportStoreSnapshot returned Exported without snapshotB64",
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
