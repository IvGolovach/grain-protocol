import Foundation
import GrainClientIOSAdapters
import GrainIOSScanner

public enum GrainReferenceAppConfigurationError: Error, Equatable, Sendable {
    case missingBundledResource(String)
    case keychainUnavailable
}

public enum GrainReferenceSnapshotPersistence: Equatable, Sendable {
    case keychain(service: String = "dev.grain.ios-reference-app.snapshot", account: String = "default")
    case file(URL)
}

public struct GrainReferenceAppConfiguration: Equatable, Sendable {
    public let trustAnchorBundleURL: URL
    public let trustAnchorID: String
    public let snapshotPersistence: GrainReferenceSnapshotPersistence
    public let demoQRCode: String?

    public init(
        trustAnchorBundleURL: URL,
        trustAnchorID: String,
        snapshotPersistence: GrainReferenceSnapshotPersistence = .keychain(),
        demoQRCode: String? = nil
    ) {
        self.trustAnchorBundleURL = trustAnchorBundleURL
        self.trustAnchorID = trustAnchorID
        self.snapshotPersistence = snapshotPersistence
        self.demoQRCode = demoQRCode
    }
}

public enum GrainReferenceAppResources {
    public static func bundled(
        snapshotPersistence: GrainReferenceSnapshotPersistence = .keychain()
    ) throws -> GrainReferenceAppConfiguration {
        let trustURL = try bundledResourceURL(
            "TRUST-ANCHOR-BUNDLE-0001",
            extension: "json"
        )
        let demoQR = try bundledTextResource("POS-QR-001", extension: "txt")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return GrainReferenceAppConfiguration(
            trustAnchorBundleURL: trustURL,
            trustAnchorID: "fixture:primary",
            snapshotPersistence: snapshotPersistence,
            demoQRCode: demoQR.isEmpty ? nil : demoQR
        )
    }

    private static func bundledResourceURL(_ name: String, extension ext: String) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Resources"
        ) else {
            throw GrainReferenceAppConfigurationError.missingBundledResource("\(name).\(ext)")
        }
        return url
    }

    private static func bundledTextResource(_ name: String, extension ext: String) throws -> String {
        let url = try bundledResourceURL(name, extension: ext)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

@MainActor
public enum GrainReferenceScannerFactory {
    public static func makeModel(configuration: GrainReferenceAppConfiguration) throws -> ScannerShellModel {
        switch configuration.snapshotPersistence {
        case let .file(fileURL):
            return try ScannerShellModel(
                trustAnchorBundleURL: configuration.trustAnchorBundleURL,
                initialTrustAnchorID: configuration.trustAnchorID,
                snapshotPersistence: GrainFileSnapshotPersistence(fileURL: fileURL)
            )
        case let .keychain(service, account):
            #if canImport(Security)
            return try ScannerShellModel(
                keychainBackedTrustAnchorBundleURL: configuration.trustAnchorBundleURL,
                initialTrustAnchorID: configuration.trustAnchorID,
                snapshotService: service,
                snapshotAccount: account
            )
            #else
            _ = service
            _ = account
            throw GrainReferenceAppConfigurationError.keychainUnavailable
            #endif
        }
    }
}
