import Foundation
import GrainClient

try runScanPreviewFixtures()
try runScanAcceptFixtures()
print("Swift client workflow fixtures: PASS")

private struct WorkflowFixture: Decodable {
    let fixtureID: String
    let workflow: String
    let strict: Bool
    let input: FixtureInput
    let expect: FixtureExpectation

    enum CodingKeys: String, CodingKey {
        case fixtureID = "fixture_id"
        case workflow
        case strict
        case input
        case expect
    }
}

private struct FixtureInput: Decodable {
    let qrStringRef: String
    let trustPubB64Ref: String?
    let trustPubB64: String?
    let acceptAttempts: Int?

    enum CodingKeys: String, CodingKey {
        case qrStringRef = "qr_string_ref"
        case trustPubB64Ref = "trust_pub_b64_ref"
        case trustPubB64 = "trust_pub_b64"
        case acceptAttempts = "accept_attempts"
    }
}

private struct FixtureExpectation: Decodable {
    let status: String
    let diag: [String]?
    let diagContains: [String]?
    let coseB64: String
    let storeMutation: String
    let acceptedRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case diag
        case diagContains = "diag_contains"
        case coseB64 = "cose_b64"
        case storeMutation = "store_mutation"
        case acceptedRecordCount = "accepted_record_count"
    }
}

private func runScanPreviewFixtures() throws {
    for fixture in try loadFixtures(kind: "scan-preview") {
        try require(fixture.workflow == "scan_preview", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let qrString = try resolveStringRef(fixture.input.qrStringRef)
        let trustPubB64 = try resolveTrustInput(fixture.input)

        let client = GrainClient()
        let preview = client.scanPreview(qrString: qrString, trustPubB64: trustPubB64)

        try require(preview.status.rawValue == fixture.expect.status, "\(fixture.fixtureID) status mismatch")
        try requireDiagnostics(preview.diag, fixture.expect, fixture.fixtureID)
        try requireCosePresence(preview.coseB64, fixture.expect.coseB64, fixture.fixtureID)
        try require(client.listAcceptedScans().isEmpty, "\(fixture.fixtureID) preview mutated storage")
    }
}

private func runScanAcceptFixtures() throws {
    for fixture in try loadFixtures(kind: "scan-accept") {
        try require(fixture.workflow == "scan_accept", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let qrString = try resolveStringRef(fixture.input.qrStringRef)
        guard let trustPubB64 = try resolveTrustInput(fixture.input) else {
            throw FixtureError.invalidReference("\(fixture.fixtureID) missing trust material")
        }

        let attempts = fixture.input.acceptAttempts ?? 1
        try require(attempts > 0, "\(fixture.fixtureID) accept_attempts must be positive")

        let client = GrainClient()
        var accepted: GrainScanAccept?
        for _ in 0..<attempts {
            accepted = client.scanAccept(qrString: qrString, trustPubB64: trustPubB64)
        }

        guard let result = accepted else {
            throw FixtureError.invalidReference("\(fixture.fixtureID) did not execute accept")
        }

        try require(result.status.rawValue == fixture.expect.status, "\(fixture.fixtureID) status mismatch")
        try requireDiagnostics(result.diag, fixture.expect, fixture.fixtureID)
        try requireCosePresence(result.coseB64, fixture.expect.coseB64, fixture.fixtureID)

        let records = client.listAcceptedScans()
        switch fixture.expect.storeMutation {
        case "accepted_scan_inserted":
            try require(!records.isEmpty, "\(fixture.fixtureID) expected persisted record")
        case "none":
            try require(records.isEmpty, "\(fixture.fixtureID) expected no persisted records")
        default:
            throw FixtureError.invalidReference("\(fixture.fixtureID) unsupported store mutation")
        }

        if let expectedCount = fixture.expect.acceptedRecordCount {
            try require(records.count == expectedCount, "\(fixture.fixtureID) accepted record count mismatch")
        }
    }
}

private func loadFixtures(kind: String) throws -> [WorkflowFixture] {
    let directory = repoRoot().appendingPathComponent("sdk/workflows/fixtures/\(kind)")
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "json" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

    try require(!urls.isEmpty, "\(kind) fixture set is empty")

    return try urls.map { url in
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(WorkflowFixture.self, from: data)
    }
}

private func resolveTrustInput(_ input: FixtureInput) throws -> String? {
    switch (input.trustPubB64Ref, input.trustPubB64) {
    case let (.some(reference), .none):
        return try resolveStringRef(reference)
    case let (.none, .some(inline)):
        return inline
    case (.none, .none):
        return nil
    case (.some, .some):
        throw FixtureError.invalidReference("trust_pub_b64_ref and trust_pub_b64 are mutually exclusive")
    }
}

private func resolveStringRef(_ ref: String) throws -> String {
    let parts = ref.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, parts[1].hasPrefix("/") else {
        throw FixtureError.invalidReference(ref)
    }

    let relativePath = String(parts[0])
    let pathComponents = relativePath.split(separator: "/", omittingEmptySubsequences: false)
    guard
        !relativePath.isEmpty,
        !relativePath.hasPrefix("/"),
        relativePath.hasPrefix("conformance/vectors/"),
        pathComponents.allSatisfy({ $0 != "." && $0 != ".." && !$0.isEmpty })
    else {
        throw FixtureError.invalidReference(ref)
    }

    let root = repoRoot()
    let vectorsRoot = root.appendingPathComponent("conformance/vectors").standardizedFileURL
    let fileURL = root.appendingPathComponent(relativePath).standardizedFileURL
    guard fileURL.path.hasPrefix(vectorsRoot.path + "/") else {
        throw FixtureError.invalidReference(ref)
    }

    let data = try Data(contentsOf: fileURL)
    var value = try JSONSerialization.jsonObject(with: data)

    for rawKey in parts[1].dropFirst().split(separator: "/") {
        let key = decodeJsonPointerToken(String(rawKey))
        guard
            let object = value as? [String: Any],
            let next = object[key]
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

private func decodeJsonPointerToken(_ token: String) -> String {
    token.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
}

private func repoRoot() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<12 {
        url.deleteLastPathComponent()
        let workflows = url.appendingPathComponent("sdk/workflows")
        if FileManager.default.fileExists(atPath: workflows.path) {
            return url
        }
    }
    fatalError("repository root not found from \(#filePath)")
}

private func requireDiagnostics(
    _ actual: [String],
    _ expectation: FixtureExpectation,
    _ fixtureID: String
) throws {
    if let expected = expectation.diag {
        try require(actual == expected, "\(fixtureID) exact diagnostics mismatch")
    }

    if let expectedContains = expectation.diagContains {
        try require(!expectedContains.isEmpty, "\(fixtureID) diag_contains must not be empty")
        for code in expectedContains {
            try require(actual.contains(code), "\(fixtureID) expected diagnostic \(code), actual \(actual)")
        }
    }
}

private func requireCosePresence(
    _ coseB64: String?,
    _ expectation: String,
    _ fixtureID: String
) throws {
    switch expectation {
    case "present":
        try require(coseB64 != nil, "\(fixtureID) expected COSE")
    case "absent":
        try require(coseB64 == nil, "\(fixtureID) expected no COSE")
    default:
        throw FixtureError.invalidReference("\(fixtureID) unsupported cose_b64 expectation")
    }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw FixtureError.assertion(message)
    }
}

private enum FixtureError: Error {
    case assertion(String)
    case invalidReference(String)
}
