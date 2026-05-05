import Foundation
import GrainClient

try runScanPreviewFixtures()
try runScanAcceptFixtures()
try runDeviceLifecycleFixtures()
try runPairingFixtures()
try runSyncBundleFixtures()
try runStoreSnapshotFixtures()
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
    let qrStringRef: String?
    let trustPubB64Ref: String?
    let trustPubB64: String?
    let acceptAttempts: Int?
    let importAttempts: Int?
    let rootLabel: String?
    let deviceLabel: String?

    enum CodingKeys: String, CodingKey {
        case qrStringRef = "qr_string_ref"
        case trustPubB64Ref = "trust_pub_b64_ref"
        case trustPubB64 = "trust_pub_b64"
        case acceptAttempts = "accept_attempts"
        case importAttempts = "import_attempts"
        case rootLabel = "root_label"
        case deviceLabel = "device_label"
    }
}

private struct FixtureExpectation: Decodable {
    let status: String
    let diag: [String]?
    let diagContains: [String]?
    let coseB64: String?
    let storeMutation: String?
    let acceptedRecordCount: Int?
    let deviceCount: UInt64?
    let revokedCount: UInt64?
    let lifecycleEventCount: UInt64?
    let rootKID: String?
    let activeAK: String?
    let deviceAK: String?
    let pairingID: String?
    let envelopeB64: String?
    let bundleB64: String?
    let snapshotB64: String?

    enum CodingKeys: String, CodingKey {
        case status
        case diag
        case diagContains = "diag_contains"
        case coseB64 = "cose_b64"
        case storeMutation = "store_mutation"
        case acceptedRecordCount = "accepted_record_count"
        case deviceCount = "device_count"
        case revokedCount = "revoked_count"
        case lifecycleEventCount = "lifecycle_event_count"
        case rootKID = "root_kid"
        case activeAK = "active_ak"
        case deviceAK = "device_ak"
        case pairingID = "pairing_id"
        case envelopeB64 = "envelope_b64"
        case bundleB64 = "bundle_b64"
        case snapshotB64 = "snapshot_b64"
    }
}

private func runScanPreviewFixtures() throws {
    for fixture in try loadFixtures(kind: "scan-preview") {
        try require(fixture.workflow == "scan_preview", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let qrString = try fixtureQRString(fixture)
        let trustPubB64 = try resolveTrustInput(fixture.input)

        let client = GrainClient()
        let preview = client.scanPreview(qrString: qrString, trustPubB64: trustPubB64)

        try require(preview.status.rawValue == fixture.expect.status, "\(fixture.fixtureID) status mismatch")
        try requireDiagnostics(preview.diag, fixture.expect, fixture.fixtureID)
        try requireCosePresence(
            preview.coseB64,
            try requiredExpectation(fixture.expect.coseB64, "cose_b64", fixture.fixtureID),
            fixture.fixtureID
        )
        try require(client.listAcceptedScans().isEmpty, "\(fixture.fixtureID) preview mutated storage")
    }
}

private func runScanAcceptFixtures() throws {
    for fixture in try loadFixtures(kind: "scan-accept") {
        try require(fixture.workflow == "scan_accept", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let qrString = try fixtureQRString(fixture)
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
        try requireCosePresence(
            result.coseB64,
            try requiredExpectation(fixture.expect.coseB64, "cose_b64", fixture.fixtureID),
            fixture.fixtureID
        )

        let records = client.listAcceptedScans()
        switch try requiredExpectation(fixture.expect.storeMutation, "store_mutation", fixture.fixtureID) {
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

private func runDeviceLifecycleFixtures() throws {
    for fixture in try loadFixtures(kind: "device-lifecycle") {
        try require(fixture.workflow == "device_lifecycle", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let client = GrainClient()
        let root = client.createRootIdentity(label: fixture.input.rootLabel ?? "root")
        try require(root.status == "Created", "\(fixture.fixtureID) root create mismatch")

        let added = client.addDeviceKey(label: fixture.input.deviceLabel ?? "device")
        try require(added.status == "Added", "\(fixture.fixtureID) device add mismatch")
        guard let deviceAK = added.deviceAK else {
            throw FixtureError.assertion("\(fixture.fixtureID) missing device ak")
        }

        let active = client.setActiveDevice(ak: deviceAK)
        try require(active.status == "Active", "\(fixture.fixtureID) active device mismatch")
        let revoked = client.revokeDeviceKey(ak: deviceAK)
        try require(revoked.status == "Revoked", "\(fixture.fixtureID) revoke mismatch")

        let lifecycle = client.clientLifecycle()
        try require(lifecycle.status == fixture.expect.status, "\(fixture.fixtureID) lifecycle status mismatch")
        try requireDiagnostics(lifecycle.diag, fixture.expect, fixture.fixtureID)
        try requirePresence(lifecycle.rootKID, fixture.expect.rootKID, "root_kid", fixture.fixtureID)
        try requirePresence(lifecycle.activeAK, fixture.expect.activeAK, "active_ak", fixture.fixtureID)
        try requirePresence(deviceAK, fixture.expect.deviceAK, "device_ak", fixture.fixtureID)
        try requireCount(lifecycle.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureID)
        try requireCount(lifecycle.revokedCount, fixture.expect.revokedCount, "revoked_count", fixture.fixtureID)
        if let expectedCount = fixture.expect.acceptedRecordCount {
            try require(
                lifecycle.acceptedRecordCount == UInt64(expectedCount),
                "\(fixture.fixtureID) accepted_record_count mismatch"
            )
        }
        try requireCount(
            lifecycle.lifecycleEventCount,
            fixture.expect.lifecycleEventCount,
            "lifecycle_event_count",
            fixture.fixtureID
        )
    }
}

private func runPairingFixtures() throws {
    for fixture in try loadFixtures(kind: "pairing") {
        try require(fixture.workflow == "pairing", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let source = GrainClient()
        try require(
            source.createRootIdentity(label: fixture.input.rootLabel ?? "root").status == "Created",
            "\(fixture.fixtureID) root create mismatch"
        )
        try require(
            source.addDeviceKey(label: fixture.input.deviceLabel ?? "device").status == "Added",
            "\(fixture.fixtureID) device add mismatch"
        )

        let envelope = source.createPairingEnvelope()
        try require(envelope.status == "Created", "\(fixture.fixtureID) envelope create mismatch")
        try requirePresence(envelope.envelopeB64, fixture.expect.envelopeB64, "envelope_b64", fixture.fixtureID)
        guard let envelopeB64 = envelope.envelopeB64 else {
            throw FixtureError.assertion("\(fixture.fixtureID) missing envelope")
        }
        let preview = source.previewPairingEnvelope(envelopeB64: envelopeB64)
        try require(preview.status == "Valid", "\(fixture.fixtureID) pairing preview mismatch")

        let target = GrainClient()
        let attempts = fixture.input.acceptAttempts ?? 1
        try require(attempts > 0, "\(fixture.fixtureID) accept_attempts must be positive")
        var paired: GrainPairingResult?
        for _ in 0..<attempts {
            paired = target.acceptPairingEnvelope(envelopeB64: envelopeB64)
        }
        guard let result = paired else {
            throw FixtureError.assertion("\(fixture.fixtureID) did not execute pairing accept")
        }
        try require(result.status == fixture.expect.status, "\(fixture.fixtureID) pairing status mismatch")
        try requireDiagnostics(result.diag, fixture.expect, fixture.fixtureID)
        try requirePresence(result.rootKID, fixture.expect.rootKID, "root_kid", fixture.fixtureID)
        try requirePresence(result.pairingID, fixture.expect.pairingID, "pairing_id", fixture.fixtureID)
        try requireCount(result.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureID)
    }
}

private func runSyncBundleFixtures() throws {
    for fixture in try loadFixtures(kind: "sync-bundle") {
        try require(fixture.workflow == "sync_bundle", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let source = GrainClient()
        try require(
            source.createRootIdentity(label: fixture.input.rootLabel ?? "root").status == "Created",
            "\(fixture.fixtureID) root create mismatch"
        )
        try require(
            source.addDeviceKey(label: fixture.input.deviceLabel ?? "device").status == "Added",
            "\(fixture.fixtureID) device add mismatch"
        )
        let trustPubB64 = try resolveTrustInput(fixture.input)
        guard let trustPubB64 = trustPubB64 else {
            throw FixtureError.invalidReference("\(fixture.fixtureID) missing trust material")
        }
        let accepted = source.scanAccept(qrString: try fixtureQRString(fixture), trustPubB64: trustPubB64)
        try require(accepted.status.rawValue == "Accepted", "\(fixture.fixtureID) scan accept mismatch")

        let exported = source.exportSyncBundle()
        try require(exported.status == "Exported", "\(fixture.fixtureID) sync export mismatch")
        try requirePresence(exported.bundleB64, fixture.expect.bundleB64, "bundle_b64", fixture.fixtureID)
        guard let bundleB64 = exported.bundleB64 else {
            throw FixtureError.assertion("\(fixture.fixtureID) missing sync bundle")
        }

        let target = GrainClient()
        let attempts = fixture.input.importAttempts ?? 1
        try require(attempts > 0, "\(fixture.fixtureID) import_attempts must be positive")
        var imported: GrainSyncResult?
        for _ in 0..<attempts {
            imported = target.importSyncBundle(bundleB64: bundleB64)
        }
        guard let result = imported else {
            throw FixtureError.assertion("\(fixture.fixtureID) did not execute sync import")
        }
        try require(result.status == fixture.expect.status, "\(fixture.fixtureID) sync status mismatch")
        try requireDiagnostics(result.diag, fixture.expect, fixture.fixtureID)
        if let expectedCount = fixture.expect.acceptedRecordCount {
            try require(
                result.acceptedRecordCount == UInt64(expectedCount),
                "\(fixture.fixtureID) accepted_record_count mismatch"
            )
        }
        try requireCount(result.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureID)
        try requireCount(
            result.lifecycleEventCount,
            fixture.expect.lifecycleEventCount,
            "lifecycle_event_count",
            fixture.fixtureID
        )
    }
}

private func runStoreSnapshotFixtures() throws {
    let empty = GrainClient()
    let emptySnapshot = empty.exportStoreSnapshot()
    try require(emptySnapshot.status == "Empty", "store snapshot empty status mismatch")
    try require(emptySnapshot.snapshotB64 == nil, "empty store snapshot must not produce payload")

    for fixture in try loadFixtures(kind: "store-snapshot") {
        try require(fixture.workflow == "store_snapshot", "\(fixture.fixtureID) workflow mismatch")
        try require(fixture.strict, "\(fixture.fixtureID) must be strict")

        let source = GrainClient()
        let target = GrainClient()
        try require(
            source.createRootIdentity(label: fixture.input.rootLabel ?? "root").status == "Created",
            "\(fixture.fixtureID) root create mismatch"
        )
        try require(
            source.addDeviceKey(label: fixture.input.deviceLabel ?? "device").status == "Added",
            "\(fixture.fixtureID) device add mismatch"
        )
        guard let trustPubB64 = try resolveTrustInput(fixture.input) else {
            throw FixtureError.invalidReference("\(fixture.fixtureID) missing trust material")
        }
        let accepted = source.scanAccept(qrString: try fixtureQRString(fixture), trustPubB64: trustPubB64)
        try require(accepted.status.rawValue == "Accepted", "\(fixture.fixtureID) scan accept mismatch")

        let exported = source.exportStoreSnapshot()
        try require(exported.status == "Exported", "\(fixture.fixtureID) snapshot export mismatch")
        try requirePresence(exported.snapshotB64, fixture.expect.snapshotB64, "snapshot_b64", fixture.fixtureID)

        guard let snapshotB64 = exported.snapshotB64 else {
            throw FixtureError.assertion("\(fixture.fixtureID) missing snapshot_b64")
        }
        let restored = target.restoreStoreSnapshot(snapshotB64: snapshotB64)
        try require(restored.status == fixture.expect.status, "\(fixture.fixtureID) snapshot restore mismatch")
        try requireDiagnostics(restored.diag, fixture.expect, fixture.fixtureID)
        try requireCount(
            restored.acceptedRecordCount,
            fixture.expect.acceptedRecordCount.map(UInt64.init),
            "accepted_record_count",
            fixture.fixtureID
        )
        try requireCount(restored.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureID)
        try requireCount(
            restored.lifecycleEventCount,
            fixture.expect.lifecycleEventCount,
            "lifecycle_event_count",
            fixture.fixtureID
        )

        let lifecycle = target.clientLifecycle()
        try require(lifecycle.status == "Ready", "\(fixture.fixtureID) lifecycle status mismatch")
        try requireCount(
            lifecycle.acceptedRecordCount,
            fixture.expect.acceptedRecordCount.map(UInt64.init),
            "accepted_record_count",
            fixture.fixtureID
        )
        try requireCount(lifecycle.deviceCount, fixture.expect.deviceCount, "device_count", fixture.fixtureID)
        try requireCount(
            lifecycle.lifecycleEventCount,
            fixture.expect.lifecycleEventCount,
            "lifecycle_event_count",
            fixture.fixtureID
        )
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

private func fixtureQRString(_ fixture: WorkflowFixture) throws -> String {
    guard let ref = fixture.input.qrStringRef else {
        throw FixtureError.invalidReference("\(fixture.fixtureID) missing qr_string_ref")
    }
    return try resolveStringRef(ref)
}

private func requiredExpectation<T>(_ value: T?, _ field: String, _ fixtureID: String) throws -> T {
    guard let value else {
        throw FixtureError.assertion("\(fixtureID) missing \(field) expectation")
    }
    return value
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

private func requirePresence(
    _ actual: String?,
    _ expectation: String?,
    _ field: String,
    _ fixtureID: String
) throws {
    switch expectation {
    case "present":
        try require(actual?.isEmpty == false, "\(fixtureID) expected \(field)")
    case "absent":
        try require(actual == nil, "\(fixtureID) expected no \(field)")
    case nil:
        return
    default:
        throw FixtureError.invalidReference("\(fixtureID) unsupported \(field) expectation")
    }
}

private func requireCount(
    _ actual: UInt64,
    _ expectation: UInt64?,
    _ field: String,
    _ fixtureID: String
) throws {
    if let expectation {
        try require(actual == expectation, "\(fixtureID) \(field) mismatch")
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
