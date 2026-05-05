import Foundation
import GrainClient
import GrainClientIOSAdapters
import GrainIOSScanner

@main
struct GrainIOSScannerSmoke {
    static func main() async throws {
        try await scannerFlowPersistsThroughSnapshot()
        try await rejectsUnknownTrustAnchorWithoutWritingSnapshot()
        print("iOS scanner shell smoke: PASS")
    }
}

private func scannerFlowPersistsThroughSnapshot() async throws {
    let qrString = try fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")
    let trustPubB64 = try fixtureString("conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64")
    let trustAnchorID = "fixture:primary"
    let trustProvider = GrainStaticTrustProvider(anchorID: trustAnchorID, trustPubB64: trustPubB64)
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

        let model = ScannerShellModel(
            trustProvider: trustProvider,
            snapshotPersistence: persistence
        )
        model.prepareLocalIdentity()
        try require(model.state.lifecycleStatus == "Ready", "lifecycle status mismatch")
        try require(model.state.deviceCount == 2, "device count mismatch")
        try require(model.state.lifecycleEventCount == 1, "lifecycle event count mismatch")
        model.prepareLocalIdentity()
        try require(model.state.deviceCount == 2, "repeat prepare duplicated device")
        try require(model.state.lifecycleEventCount == 1, "repeat prepare duplicated lifecycle event")

        model.updateTrustAnchorID(trustAnchorID)
        model.receiveCameraPayload(cameraPayload)
        model.preview()

        try require(model.state.previewStatus == .verified, "preview status mismatch")
        try require(model.state.canAccept, "verified preview did not enable accept")
        try require(model.state.diagnostics.isEmpty, "verified preview diagnostics not empty")

        model.accept()

        try require(model.state.acceptStatus == .accepted, "accept status mismatch")
        try require(model.state.acceptedCount == 1, "accepted count mismatch")
        try require(!(model.state.acceptedScanID?.isEmpty ?? true), "accepted scan id missing")
        try require(model.state.snapshotStatus == "Exported", "snapshot export status mismatch")
        try require(try persistence.loadSnapshotB64() != nil, "snapshot was not persisted")

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
    let trustPubB64 = try fixtureString("conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64")
    let trustProvider = GrainStaticTrustProvider(anchorID: "fixture:primary", trustPubB64: trustPubB64)
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
