import Foundation
import GrainClient

#if canImport(Security)
import Security
#endif

public protocol GrainSnapshotPersistence: Sendable {
    func loadSnapshotB64() throws -> String?
    func saveSnapshotB64(_ snapshotB64: String) throws
    func clearSnapshot() throws
}

public enum GrainSnapshotPersistenceError: Error, Equatable, Sendable {
    case invalidUtf8
    case missingExportedSnapshot
    case keychainStatus(Int32)
}

public protocol GrainSnapshotClient: AnyObject {
    func exportStoreSnapshot() -> GrainStoreSnapshotResult
    func restoreStoreSnapshot(snapshotB64: String) -> GrainStoreSnapshotResult
}

extension GrainClient: GrainSnapshotClient {}

public struct GrainSnapshotCoordinator: Sendable {
    private let persistence: any GrainSnapshotPersistence

    public init(persistence: any GrainSnapshotPersistence) {
        self.persistence = persistence
    }

    public func restore(into client: any GrainSnapshotClient) throws -> GrainStoreSnapshotResult? {
        guard let snapshotB64 = try persistence.loadSnapshotB64() else {
            return nil
        }
        return client.restoreStoreSnapshot(snapshotB64: snapshotB64)
    }

    @discardableResult
    public func persist(from client: any GrainSnapshotClient) throws -> GrainStoreSnapshotResult {
        let result = client.exportStoreSnapshot()
        if result.status == "Exported" {
            guard let snapshotB64 = result.snapshotB64 else {
                throw GrainSnapshotPersistenceError.missingExportedSnapshot
            }
            try persistence.saveSnapshotB64(snapshotB64)
        } else if result.status == "Empty" {
            try persistence.clearSnapshot()
        }
        return result
    }
}

public struct GrainLocalSnapshotStore: Sendable {
    private let persistence: any GrainSnapshotPersistence
    private let coordinator: GrainSnapshotCoordinator

    public init(persistence: any GrainSnapshotPersistence) {
        self.persistence = persistence
        self.coordinator = GrainSnapshotCoordinator(persistence: persistence)
    }

    public func restore(into client: any GrainSnapshotClient) throws -> GrainStoreSnapshotResult? {
        try coordinator.restore(into: client)
    }

    @discardableResult
    public func save(from client: any GrainSnapshotClient) throws -> GrainStoreSnapshotResult {
        try coordinator.persist(from: client)
    }

    public func clear() throws {
        try persistence.clearSnapshot()
    }
}

public struct GrainFileSnapshotPersistence: GrainSnapshotPersistence, Sendable {
    public let fileURL: URL
    public let excludeFromBackup: Bool

    public init(fileURL: URL, excludeFromBackup: Bool = true) {
        self.fileURL = fileURL
        self.excludeFromBackup = excludeFromBackup
    }

    public static func applicationSupport(
        subdirectory: String = "Grain",
        filename: String = "client-store.snapshot"
    ) throws -> GrainFileSnapshotPersistence {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return GrainFileSnapshotPersistence(
            fileURL: base.appendingPathComponent(subdirectory, isDirectory: true)
                .appendingPathComponent(filename, isDirectory: false)
        )
    }

    public func loadSnapshotB64() throws -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        guard let snapshotB64 = String(data: data, encoding: .utf8) else {
            throw GrainSnapshotPersistenceError.invalidUtf8
        }
        let trimmed = snapshotB64.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func saveSnapshotB64(_ snapshotB64: String) throws {
        guard let data = snapshotB64.data(using: .utf8) else {
            throw GrainSnapshotPersistenceError.invalidUtf8
        }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
        try applyPlatformProtection()
    }

    public func clearSnapshot() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func applyPlatformProtection() throws {
        if excludeFromBackup {
            var resourceURL = fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try resourceURL.setResourceValues(values)

            var directoryURL = fileURL.deletingLastPathComponent()
            try directoryURL.setResourceValues(values)
        }

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
        #endif
    }
}

#if canImport(Security)
public enum GrainKeychainAccessibility: Sendable {
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly
    case whenUnlocked
    case afterFirstUnlock

    fileprivate var secAttrValue: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        }
    }
}

public struct GrainKeychainSnapshotPersistence: GrainSnapshotPersistence, Sendable {
    public let service: String
    public let account: String
    public let accessGroup: String?
    private let accessible: GrainKeychainAccessibility

    public init(
        service: String = "dev.grain.client.snapshot",
        account: String = "default",
        accessGroup: String? = nil,
        accessible: GrainKeychainAccessibility = .whenUnlockedThisDeviceOnly
    ) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.accessible = accessible
    }

    public func loadSnapshotB64() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw GrainSnapshotPersistenceError.keychainStatus(status)
        }
        guard
            let data = item as? Data,
            let snapshotB64 = String(data: data, encoding: .utf8)
        else {
            throw GrainSnapshotPersistenceError.invalidUtf8
        }
        let trimmed = snapshotB64.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public func saveSnapshotB64(_ snapshotB64: String) throws {
        guard let data = snapshotB64.data(using: .utf8) else {
            throw GrainSnapshotPersistenceError.invalidUtf8
        }
        try saveSnapshotData(data, retryAfterMissingUpdate: true)
    }

    private func saveSnapshotData(_ data: Data, retryAfterMissingUpdate: Bool) throws {
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = accessible.secAttrValue

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess {
            return
        }
        if status == errSecDuplicateItem {
            let update: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessible.secAttrValue,
            ]
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, update as CFDictionary)
            if updateStatus == errSecItemNotFound && retryAfterMissingUpdate {
                try saveSnapshotData(data, retryAfterMissingUpdate: false)
                return
            }
            guard updateStatus == errSecSuccess else {
                throw GrainSnapshotPersistenceError.keychainStatus(updateStatus)
            }
            return
        }
        throw GrainSnapshotPersistenceError.keychainStatus(status)
    }

    public func clearSnapshot() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw GrainSnapshotPersistenceError.keychainStatus(status)
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
#endif
