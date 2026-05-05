import Foundation
import GrainIOSScanner

@main
struct GrainIOSScannerSmoke {
    static func main() async throws {
        try await acceptsOnlyAfterVerifiedPreview()
        print("iOS scanner shell smoke: PASS")
    }
}

private func acceptsOnlyAfterVerifiedPreview() async throws {
    let qrString = try fixtureString("conformance/vectors/qr/POS-QR-001.json#/input/qr_string")
    let trustPubB64 = try fixtureString("conformance/vectors/cose/POS-COSE-001.json#/input/pub_b64")
    let camera = InjectedCameraScanAdapter(qrStrings: [qrString])
    guard let cameraPayload = try await camera.nextScanPayload() else {
        throw FixtureError.assertion("camera payload missing")
    }

    try await MainActor.run {
        let guarded = ScannerShellModel()
        guarded.accept()
        try require(!guarded.state.canAccept, "accept guard enabled accept")
        try require(guarded.state.acceptStatus == nil, "accept guard set accept status")
        try require(
            guarded.state.diagnostics == [scannerAcceptRequiresVerifiedPreviewDiag],
            "accept guard diagnostics mismatch"
        )

        let model = ScannerShellModel()
        model.prepareLocalIdentity()
        try require(model.state.lifecycleStatus == "Ready", "lifecycle status mismatch")
        try require(model.state.deviceCount == 2, "device count mismatch")
        try require(model.state.lifecycleEventCount == 1, "lifecycle event count mismatch")
        model.prepareLocalIdentity()
        try require(model.state.deviceCount == 2, "repeat prepare duplicated device")
        try require(model.state.lifecycleEventCount == 1, "repeat prepare duplicated lifecycle event")

        model.updateTrustPubB64(trustPubB64)
        model.receiveCameraPayload(cameraPayload)
        model.preview()

        try require(model.state.previewStatus == .verified, "preview status mismatch")
        try require(model.state.canAccept, "verified preview did not enable accept")
        try require(model.state.diagnostics.isEmpty, "verified preview diagnostics not empty")

        model.accept()

        try require(model.state.acceptStatus == .accepted, "accept status mismatch")
        try require(model.state.acceptedCount == 1, "accepted count mismatch")
        try require(!(model.state.acceptedScanID?.isEmpty ?? true), "accepted scan id missing")

        model.accept()

        try require(model.state.acceptStatus == .alreadyAccepted, "repeat accept status mismatch")
        try require(model.state.acceptedCount == 1, "repeat accept duplicated record")
    }
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
