import Foundation
import GrainClientIOSAdapters
import GrainIOSScanner
import GrainIOSStarterCore

try await MainActor.run {
    try starterPreviewsAcceptsPersistsAndRestores()
}
print("iOS starter smoke: PASS")

@MainActor
private func starterPreviewsAcceptsPersistsAndRestores() throws {
    let snapshotURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("grain-ios-starter-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("client-store.snapshot", isDirectory: false)
    let persistence = GrainFileSnapshotPersistence(fileURL: snapshotURL)
    defer { try? persistence.clearSnapshot() }

    let model = try ScannerShellModel(
        trustAnchorBundleURL: StarterResources.trustAnchorBundleURL,
        initialTrustAnchorID: StarterResources.trustAnchorID,
        snapshotPersistence: persistence
    )
    model.prepareLocalIdentity(rootLabel: "ios-starter", deviceLabel: "phone")
    try require(model.state.lifecycleStatus == "Ready", "starter did not prepare identity")
    try require(model.state.snapshotStatus == "Exported", "starter did not persist identity snapshot")

    let sample = StarterResources.sampleQrString
    try require(sample.hasPrefix("GR1:"), "sample QR missing")
    model.updateQrString(sample)
    model.preview()
    try require(model.state.previewStatus == .verified, "starter preview did not verify")
    try require(model.state.canAccept, "starter preview did not enable accept")

    model.accept()
    try require(model.state.acceptStatus == .accepted, "starter accept did not write scan")
    try require(model.state.acceptedCount == 1, "starter accepted scan count mismatch")
    try require(model.state.snapshotStatus == "Exported", "starter did not persist accepted scan")

    let exported = model.exportSyncBundleForShare()
    try require(exported.status == "Exported", "starter export status mismatch")

    let restored = try ScannerShellModel(
        trustAnchorBundleURL: StarterResources.trustAnchorBundleURL,
        initialTrustAnchorID: StarterResources.trustAnchorID,
        snapshotPersistence: persistence
    )
    restored.restorePersistedSnapshot()
    try require(restored.state.snapshotStatus == "Restored", "starter restore status mismatch")
    try require(restored.state.acceptedCount == 1, "starter restore did not load accepted scan")

    restored.updateQrString(sample)
    restored.preview()
    restored.accept()
    try require(restored.state.acceptStatus == .alreadyAccepted, "starter repeat accept was not idempotent")
    try require(restored.state.acceptedCount == 1, "starter repeat accept duplicated scan")
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SmokeError.assertion(message)
    }
}

private enum SmokeError: Error {
    case assertion(String)
}
