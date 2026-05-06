import Foundation
import GrainClient
import GrainClientIOSAdapters
import GrainIOSScanner

@main
struct GrainIOSScannerSmoke {
    static func main() async throws {
        try await MainActor.run {
            try rejectsNonFileTrustBundleURL()
        }
        try await cameraAdapterHandoffUpdatesShellState()
        try await scannerFlowPersistsThroughSnapshot()
        try await rejectsUnknownTrustAnchorWithoutWritingSnapshot()
        print("iOS scanner shell smoke: PASS")
    }
}

@MainActor
private func rejectsNonFileTrustBundleURL() throws {
    let persistence = GrainFileSnapshotPersistence(fileURL: temporarySnapshotURL())
    defer { try? persistence.clearSnapshot() }

    do {
        _ = try ScannerShellModel(
            trustAnchorBundleURL: URL(string: "grain://trust-anchor-bundle")!,
            initialTrustAnchorID: "fixture:primary",
            snapshotPersistence: persistence
        )
        throw FixtureError.assertion("non-file trust bundle URL was accepted")
    } catch ScannerShellConfigurationError.nonFileTrustAnchorBundleURL {
        return
    }
}

@MainActor
private func cameraAdapterHandoffUpdatesShellState() async throws {
    let pastedModel = ScannerShellModel()
    pastedModel.receiveCameraPayload(CameraScanPayload(qrString: "gr1:camera", source: .camera))
    pastedModel.updateQrString("gr1:pasted")
    try require(pastedModel.state.scanSource == nil, "paste did not clear camera source")

    let camera = InjectedCameraScanAdapter(qrStrings: ["gr1:test-payload"])
    let model = ScannerShellModel()
    let payload = try await model.captureNextCameraPayload(from: camera)
    try require(
        payload == CameraScanPayload(qrString: "gr1:test-payload", source: .injected),
        "camera payload mismatch"
    )
    try require(model.state.qrString == "gr1:test-payload", "camera payload was not handed to shell state")
    try require(model.state.scanSource == .injected, "camera source was not recorded")
    try require(model.state.previewStatus == nil, "camera payload did not reset preview")
    try require(model.state.acceptStatus == nil, "camera payload did not reset accept")
    try require(model.state.acceptedScanID == nil, "camera payload did not reset accepted scan id")
    try require(!model.state.canAccept, "camera payload left accept enabled")
    try require(model.state.diagnostics.isEmpty, "camera payload did not clear diagnostics")

    let emptyModel = ScannerShellModel()
    emptyModel.receiveCameraPayload(CameraScanPayload(qrString: "gr1:existing", source: .camera))
    let emptyCamera = InjectedCameraScanAdapter(qrStrings: [])
    let emptyPayload = try await emptyModel.captureNextCameraPayload(from: emptyCamera)
    try require(emptyPayload == nil, "empty camera adapter produced a payload")
    try require(emptyModel.state.qrString == "gr1:existing", "empty camera adapter mutated qr state")
    try require(emptyModel.state.scanSource == .camera, "empty camera adapter mutated source")
}

@MainActor
private func scannerFlowPersistsThroughSnapshot() async throws {
    let qrString = try fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")
    let trustAnchorBundleURL = try fixtureFileURL("sdk/trust/fixtures/TRUST-ANCHOR-BUNDLE-0001.json")
    let trustAnchorBundleJSON = try fixtureFileContents("sdk/trust/fixtures/TRUST-ANCHOR-BUNDLE-0001.json")
    let trustAnchorID = "fixture:primary"
    let trustProvider = try GrainStaticTrustProvider(bundleJSON: trustAnchorBundleJSON)
    let persistence = GrainFileSnapshotPersistence(fileURL: temporarySnapshotURL())
    let guardedPersistence = GrainFileSnapshotPersistence(fileURL: temporarySnapshotURL())
    defer { try? persistence.clearSnapshot() }
    defer { try? guardedPersistence.clearSnapshot() }

    let camera = InjectedCameraScanAdapter(qrStrings: [qrString])
    guard let cameraPayload = try await camera.nextScanPayload() else {
        throw FixtureError.assertion("camera payload missing")
    }

    try await MainActor.run {
        let guarded = ScannerShellModel(snapshotPersistence: guardedPersistence)
        guarded.accept()
        try require(!guarded.state.canAccept, "accept guard enabled accept")
        try require(guarded.state.acceptStatus == nil, "accept guard set accept status")
        try require(guarded.state.acceptedCount == 0, "accept guard wrote accepted records")
        try require(try guardedPersistence.loadSnapshotB64() == nil, "accept guard persisted snapshot")
        try require(
            guarded.state.diagnostics == [scannerAcceptRequiresVerifiedPreviewDiag],
            "accept guard diagnostics mismatch"
        )

        let model = try ScannerShellModel(
            trustAnchorBundleURL: trustAnchorBundleURL,
            initialTrustAnchorID: trustAnchorID,
            snapshotPersistence: persistence
        )
        model.prepareLocalIdentity()
        try require(model.state.lifecycleStatus == "Ready", "lifecycle status mismatch")
        try require(model.state.deviceCount == 2, "device count mismatch")
        try require(model.state.lifecycleEventCount == 1, "lifecycle event count mismatch")
        model.prepareLocalIdentity()
        try require(model.state.deviceCount == 2, "repeat prepare duplicated device")
        try require(model.state.lifecycleEventCount == 1, "repeat prepare duplicated lifecycle event")

        model.receiveCameraPayload(cameraPayload)
        model.preview()

        try require(model.state.previewStatus == .verified, "preview status mismatch")
        try require(model.state.canAccept, "verified preview did not enable accept")
        try require(model.state.diagnostics.isEmpty, "verified preview diagnostics not empty")

        model.accept()

        try require(model.state.acceptStatus == .accepted, "accept status mismatch")
        try require(model.state.acceptedCount == 1, "accepted count mismatch")
        try require(!(model.state.acceptedScanID?.isEmpty ?? true), "accepted scan id missing")
        try require(model.state.acceptedScans.count == 1, "accepted scan list mismatch")
        try require(model.state.acceptedScans.first?.id == model.state.acceptedScanID, "accepted scan list id mismatch")
        try require(model.state.snapshotStatus == "Exported", "snapshot export status mismatch")
        try require(try persistence.loadSnapshotB64() != nil, "snapshot was not persisted")

        let exported = model.exportSyncBundleForShare()
        try require(exported.status == "Exported", "sync export status mismatch")
        try require(exported.bundleB64 != nil, "sync export bundle missing")
        try require(model.state.exportStatus == "Exported", "state export status mismatch")
        try require(model.state.exportAcceptedCount == 1, "state export accepted count mismatch")
        try require(model.state.exportDeviceCount == 2, "state export device count mismatch")
        try require(model.state.exportLifecycleEventCount == 1, "state export lifecycle count mismatch")

        model.accept()

        try require(model.state.acceptStatus == .alreadyAccepted, "repeat accept status mismatch")
        try require(model.state.acceptedCount == 1, "repeat accept duplicated record")

        let restored = ScannerShellModel(
            client: GrainClient(),
            trustProvider: trustProvider,
            snapshotPersistence: persistence
        )
        restored.restorePersistedSnapshot()
        try require(restored.state.snapshotStatus == "Restored", "snapshot restore status mismatch")
        try require(restored.state.acceptedCount == 1, "restored accepted count mismatch")
        try require(restored.state.acceptedScans.count == 1, "restored accepted scan list mismatch")
        try require(restored.state.lifecycleStatus == "Ready", "restored lifecycle status mismatch")

        restored.updateTrustAnchorID(trustAnchorID)
        restored.receiveCameraPayload(cameraPayload)
        restored.preview()
        restored.accept()
        try require(restored.state.acceptStatus == .alreadyAccepted, "restored repeat accept mismatch")
        try require(restored.state.acceptedCount == 1, "restored repeat accept duplicated record")
    }
}

private func rejectsUnknownTrustAnchorWithoutWritingSnapshot() async throws {
    let qrString = try fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")
    let trustAnchorBundleJSON = try fixtureFileContents("sdk/trust/fixtures/TRUST-ANCHOR-BUNDLE-0001.json")
    let trustProvider = try GrainStaticTrustProvider(bundleJSON: trustAnchorBundleJSON)
    let persistence = GrainFileSnapshotPersistence(fileURL: temporarySnapshotURL())
    defer { try? persistence.clearSnapshot() }

    try await MainActor.run {
        let blank = ScannerShellModel(
            trustProvider: trustProvider,
            snapshotPersistence: persistence
        )
        blank.updateTrustAnchorID(" ")
        blank.receiveCameraPayload(CameraScanPayload(qrString: qrString, source: .injected))
        blank.preview()
        try require(blank.state.previewStatus == .rejected, "blank anchor preview did not reject")
        try require(
            blank.state.diagnostics == ["SDK_ERR_TRUST_ANCHOR_REQUIRED"],
            "blank anchor diagnostics mismatch"
        )
        try require(blank.state.acceptedCount == 0, "blank anchor wrote accepted records")
        try require(try persistence.loadSnapshotB64() == nil, "blank anchor persisted snapshot")

        let unknown = ScannerShellModel(
            trustProvider: trustProvider,
            snapshotPersistence: persistence
        )
        unknown.updateTrustAnchorID("fixture:missing")
        unknown.receiveCameraPayload(CameraScanPayload(qrString: qrString, source: .injected))
        unknown.preview()
        try require(unknown.state.previewStatus == .rejected, "unknown anchor preview did not reject")
        try require(
            unknown.state.diagnostics == ["SDK_ERR_TRUST_ANCHOR_NOT_FOUND"],
            "unknown anchor diagnostics mismatch"
        )
        unknown.accept()
        try require(unknown.state.acceptStatus == nil, "unknown anchor accept status was set")
        try require(
            unknown.state.diagnostics == ["SDK_ERR_TRUST_ANCHOR_NOT_FOUND"],
            "unknown anchor diagnostic was overwritten"
        )
        try require(unknown.state.acceptedCount == 0, "unknown anchor wrote accepted records")
        try require(try persistence.loadSnapshotB64() == nil, "unknown anchor persisted snapshot")
    }
}

private func fixtureFileContents(_ path: String) throws -> String {
    let fileURL = try fixtureFileURL(path)
    let data = try Data(contentsOf: fileURL)
    guard let contents = String(data: data, encoding: .utf8) else {
        throw FixtureError.invalidReference(path)
    }
    return contents
}

private func fixtureFileURL(_ path: String) throws -> URL {
    let root = try repoRoot()
    return root.appendingPathComponent(path).standardizedFileURL
}

private func temporarySnapshotURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("grain-ios-scanner-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("client-store.snapshot", isDirectory: false)
}

private func fixtureString(_ ref: String) throws -> String {
    let parts = ref.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, parts[1].hasPrefix("/") else {
        throw FixtureError.invalidReference(ref)
    }

    let root = try repoRoot()
    let fileURL = root.appendingPathComponent(String(parts[0])).standardizedFileURL
    let data = try Data(contentsOf: fileURL)
    var value = try JSONSerialization.jsonObject(with: data)

    for rawToken in parts[1].dropFirst().split(separator: "/") {
        let token = String(rawToken)
            .replacingOccurrences(of: "~1", with: "/")
            .replacingOccurrences(of: "~0", with: "~")
        guard
            let object = value as? [String: Any],
            let next = object[token]
        else {
            throw FixtureError.invalidReference(ref)
        }
        value = next
    }

    guard let string = value as? String else {
        throw FixtureError.invalidReference(ref)
    }
    return string
}

private func repoRoot() throws -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<12 {
        url.deleteLastPathComponent()
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("sdk/workflows").path) {
            return url
        }
    }
    throw FixtureError.repoRootMissing
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw FixtureError.assertion(message)
    }
}

private enum FixtureError: Error {
    case assertion(String)
    case invalidReference(String)
    case repoRootMissing
}
