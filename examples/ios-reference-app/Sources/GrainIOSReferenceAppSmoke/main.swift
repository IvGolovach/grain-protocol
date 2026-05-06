import Foundation
import GrainIOSReferenceAppCore
import GrainIOSScanner

@main
struct GrainIOSReferenceAppSmoke {
    static func main() async throws {
        try await MainActor.run {
            try referenceAppBootsScansPersistsAndRestores()
        }
        print("iOS reference app smoke: PASS")
    }
}

@MainActor
private func referenceAppBootsScansPersistsAndRestores() throws {
    let snapshotURL = temporarySnapshotURL()
    let configuration = try GrainReferenceAppResources.bundled(
        snapshotPersistence: .file(snapshotURL)
    )
    defer { try? FileManager.default.removeItem(at: snapshotURL) }

    let session = GrainReferenceScannerSession(configuration: configuration)
    session.start()
    guard let model = session.model else {
        throw SmokeError.assertion("reference app did not create scanner model")
    }

    try require(session.launchDiagnostic == nil, "reference app launch diagnostic was set")
    try require(model.state.lifecycleStatus == "Ready", "reference app did not prepare local identity")
    try require(model.state.deviceCount == 2, "reference app device count mismatch")

    session.loadDemoScanAndPreview()
    try require(model.state.previewStatus?.rawValue == "Verified", "demo QR did not verify")
    try require(model.state.canAccept, "verified demo QR did not enable accept")
    model.accept()
    try require(model.state.acceptStatus?.rawValue == "Accepted", "demo QR was not accepted")
    try require(model.state.acceptedCount == 1, "accepted scan count mismatch")
    try require(model.state.snapshotStatus == "Exported", "accepted scan did not persist snapshot")

    let restoredSession = GrainReferenceScannerSession(configuration: configuration)
    restoredSession.start()
    guard let restoredModel = restoredSession.model else {
        throw SmokeError.assertion("reference app did not restore scanner model")
    }
    try require(restoredModel.state.snapshotStatus == "Restored", "reference app did not restore snapshot")
    try require(restoredModel.state.acceptedCount == 1, "restored scan count mismatch")

    restoredSession.loadDemoScanAndPreview()
    restoredModel.accept()
    try require(restoredModel.state.acceptStatus?.rawValue == "AlreadyAccepted", "restored accept was not idempotent")
    try require(restoredModel.state.acceptedCount == 1, "restored accept duplicated scan")
}

private func temporarySnapshotURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("grain-ios-reference-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("snapshot.b64")
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SmokeError.assertion(message)
    }
}

private enum SmokeError: Error, CustomStringConvertible {
    case assertion(String)

    var description: String {
        switch self {
        case let .assertion(message):
            return message
        }
    }
}
