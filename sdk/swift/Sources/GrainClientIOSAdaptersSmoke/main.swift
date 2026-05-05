import Foundation
import GrainClient
import GrainClientIOSAdapters

@main
struct GrainClientIOSAdaptersSmoke {
    static func main() throws {
        try filePersistenceRestoresOpaqueClientSnapshot()
        try emptySnapshotClearsPersistedState()
        print("swift ios adapters smoke: PASS")
    }
}

private func filePersistenceRestoresOpaqueClientSnapshot() throws {
    let persistence = GrainFileSnapshotPersistence(fileURL: temporarySnapshotURL())
    let coordinator = GrainSnapshotCoordinator(persistence: persistence)
    defer { try? persistence.clearSnapshot() }

    let source = GrainClient()
    _ = source.createRootIdentity(label: "phone")
    _ = source.addDeviceKey(label: "scanner")

    let exported = try coordinator.persist(from: source)
    try require(exported.status == "Exported", "snapshot export status mismatch")
    try require(exported.snapshotB64 != nil, "snapshot payload missing")
    try require(try persistence.loadSnapshotB64() != nil, "snapshot was not persisted")

    let restored = GrainClient()
    let restoreResult = try coordinator.restore(into: restored)
    try require(restoreResult?.status == "Restored", "snapshot restore status mismatch")

    let lifecycle = restored.clientLifecycle()
    try require(lifecycle.status == "Ready", "restored lifecycle status mismatch")
    try require(lifecycle.deviceCount == 2, "restored device count mismatch")
    try require(lifecycle.lifecycleEventCount == 1, "restored lifecycle event count mismatch")
}

private func emptySnapshotClearsPersistedState() throws {
    let persistence = GrainFileSnapshotPersistence(fileURL: temporarySnapshotURL())
    let coordinator = GrainSnapshotCoordinator(persistence: persistence)
    defer { try? persistence.clearSnapshot() }

    try persistence.saveSnapshotB64("stale")
    try require(try persistence.loadSnapshotB64() != nil, "seed snapshot missing")

    let empty = GrainClient()
    let exported = try coordinator.persist(from: empty)
    try require(exported.status == "Empty", "empty snapshot status mismatch")
    try require(try persistence.loadSnapshotB64() == nil, "empty snapshot did not clear persisted state")
}

private func temporarySnapshotURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("grain-ios-adapters-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("client-store.snapshot", isDirectory: false)
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw SmokeError.assertion(message)
    }
}

private enum SmokeError: Error {
    case assertion(String)
}
