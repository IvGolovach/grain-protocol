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
    guard let demoQRCode = configuration.demoQRCode else {
        throw SmokeError.assertion("reference app demo QR missing")
    }

    let session = GrainReferenceScannerSession(configuration: configuration)
    session.start()
    guard let model = session.model else {
        throw SmokeError.assertion("reference app did not create scanner model")
    }

    try require(session.launchDiagnostic == nil, "reference app launch diagnostic was set")
    try require(model.state.lifecycleStatus == "Ready", "reference app did not prepare local identity")
    try require(model.state.deviceCount == 2, "reference app device count mismatch")
    try require(model.state.lifecycleEventCount == 1, "reference app lifecycle event count mismatch")
    try require(!model.state.canAccept, "accept was enabled before preview")

    model.accept()
    try require(model.state.acceptStatus == nil, "accept guard set accept status")
    try require(model.state.acceptedCount == 0, "accept guard wrote a saved scan")
    try require(
        model.state.diagnostics == [scannerAcceptRequiresVerifiedPreviewDiag],
        "accept guard diagnostics mismatch"
    )

    session.loadDemoScanAndPreview()
    try require(model.state.previewStatus?.rawValue == "Verified", "demo QR did not verify")
    try require(model.state.scanSource == .injected, "demo QR source was not recorded")
    try require(model.state.canAccept, "verified demo QR did not enable accept")

    model.clearScanInput()
    try require(model.state.qrString.isEmpty, "clear did not empty QR input")
    try require(model.state.previewStatus == nil, "clear did not reset preview")
    try require(!model.state.canAccept, "clear left accept enabled")

    session.previewManualQRCode(demoQRCode)
    try require(model.state.previewStatus?.rawValue == "Verified", "manual paste QR did not verify")
    try require(model.state.scanSource == nil, "manual paste did not use manual handoff source")
    try require(model.state.canAccept, "manual verified QR did not enable accept")

    model.accept()
    try require(model.state.acceptStatus?.rawValue == "Accepted", "manual paste QR was not accepted")
    try require(model.state.acceptedCount == 1, "accepted scan count mismatch")
    try require(model.state.snapshotStatus == "Exported", "accepted scan did not persist snapshot")

    let debug = model.exportDebugSummary()
    try require(debug.status == "Exported", "debug export status mismatch")
    try require(debug.acceptedRecordCount == 1, "debug export accepted count mismatch")
    try require(debug.deviceCount == 2, "debug export device count mismatch")
    try require(debug.lifecycleEventCount == 1, "debug export lifecycle count mismatch")
    try require(debug.diagnostics == model.state.diagnostics, "debug diagnostics mismatch")
    try require(debug.exposesDiagnosticsOnly, "debug summary exposed export material")

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

    let restoredDebug = restoredModel.exportDebugSummary()
    try require(restoredDebug.acceptedRecordCount == 1, "restored debug export accepted count mismatch")
    try require(restoredDebug.exposesDiagnosticsOnly, "restored debug summary exposed export material")
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

private extension ScannerExportDebugSummary {
    var exposesDiagnosticsOnly: Bool {
        let exposedLabels = Set(Mirror(reflecting: self).children.compactMap(\.label))
        let forbiddenLabels = Set([
            "bundleB64",
            "snapshotB64",
            "trustAnchorBundle",
            "trustMaterial",
            "acceptedScanID",
            "acceptedScans",
        ])
        return exposedLabels.isDisjoint(with: forbiddenLabels)
    }
}
