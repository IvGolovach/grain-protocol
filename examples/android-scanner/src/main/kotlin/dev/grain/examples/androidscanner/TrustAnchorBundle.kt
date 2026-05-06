package dev.grain.examples.androidscanner

import dev.grain.GrainStaticTrustProvider
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.Path

const val SCANNER_TRUST_ANCHOR_BUNDLE_FILE_REQUIRED_DIAG =
    "SDK_ERR_EXAMPLE_TRUST_ANCHOR_BUNDLE_FILE_REQUIRED"

class ScannerTrustAnchorBundleLoadException :
    IllegalArgumentException(SCANNER_TRUST_ANCHOR_BUNDLE_FILE_REQUIRED_DIAG)

fun scannerTrustProviderFromBundleJson(bundleJson: String): GrainStaticTrustProvider =
    GrainStaticTrustProvider.fromBundleJson(bundleJson)

fun scannerTrustProviderFromBundleStream(bundleStream: InputStream): GrainStaticTrustProvider {
    val bundleJson = bundleStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
    return scannerTrustProviderFromBundleJson(bundleJson)
}

fun scannerTrustProviderFromLocalBundlePath(bundlePath: Path): GrainStaticTrustProvider {
    val localPath = bundlePath.toAbsolutePath().normalize()
    if (!Files.isRegularFile(localPath)) {
        throw ScannerTrustAnchorBundleLoadException()
    }
    return scannerTrustProviderFromBundleJson(Files.readString(localPath))
}
