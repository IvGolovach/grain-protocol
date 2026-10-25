import CryptoKit
import Foundation
import GrainClientIOSAdapters
import GrainSignedFood

enum SmokeError: Error { case assertion(String), injected }
func check(_ condition: @autoclosure () -> Bool, _ label: String) throws {
    if !condition() { throw SmokeError.assertion(label) }
}

final class FaultStore: GrainSnapshotPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var saved: String?
    private var writes = 0
    private var failAt: Int?
    private var afterWrite = false
    private var failRead = false
    func inject(offset: Int, afterWrite: Bool = false, failRead: Bool = false) {
        lock.withLock { failAt = writes + offset; self.afterWrite = afterWrite; self.failRead = failRead }
    }
    func allowReads() { lock.withLock { failRead = false } }
    func loadSnapshotB64() throws -> String? {
        try lock.withLock { if failRead { throw SmokeError.injected }; return saved }
    }
    func saveSnapshotB64(_ value: String) throws {
        try lock.withLock {
            writes += 1
            let fail = writes == failAt
            if fail && !afterWrite { throw SmokeError.injected }
            saved = value
            if fail { throw SmokeError.injected }
        }
    }
    func clearSnapshot() { lock.withLock { saved = nil } }
}

final class TestSigner: GrainFoodSigner, @unchecked Sendable {
    private let key: Curve25519.Signing.PrivateKey
    private let lock = NSLock()
    private var messages: [Data] = []
    private var shouldFail = false
    init(seed: UInt8? = nil) {
        // Public deterministic fixture seed is only for the separate-process test.
        if let seed { key = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: seed, count: 32)) }
        else { key = Curve25519.Signing.PrivateKey() }
    }
    var publicKey: Data { key.publicKey.rawRepresentation }
    var count: Int { lock.withLock { messages.count } }
    var last: Data? { lock.withLock { messages.last } }
    func failNext() { lock.withLock { shouldFail = true } }
    func signPreparedMessage(_ message: Data) throws -> Data {
        try lock.withLock {
            messages.append(message)
            if shouldFail { shouldFail = false; throw SmokeError.injected }
            return try key.signature(for: message)
        }
    }
}

func food(_ id: String, _ kcal: Int64 = 100) -> GrainConfirmedFood {
    GrainConfirmedFood(operationId: id, source: .estimated, meanKcal: kcal, varianceKcal: 4)
}

@main
@MainActor
struct SignedFoodSmoke {
    static func storageFailure(_ operation: () async throws -> GrainSignedFoodReceipt) async throws {
        do { _ = try await operation(); throw SmokeError.assertion("storage failure missing") }
        catch GrainSignedFoodError.persistenceFailed {}
    }

    static func main() async throws {
        if CommandLine.arguments.dropFirst().first == "--resume" {
            let output = URL(fileURLWithPath: CommandLine.arguments[2])
            let signer = TestSigner(seed: 86)
            let persistence = GrainFileSnapshotPersistence(fileURL: output.appendingPathComponent("private.snapshot"))
            let wallet = try GrainSignedFoodWallet(trustedRootPublicKey: signer.publicKey, persistence: persistence)
            let repeated = try await wallet.record(food("confirmed-meal", 700), using: signer)
            try check(repeated.status == "AlreadyCommitted" && signer.count == 0, "separate process restores receipt")
            let next = try await wallet.record(food("after-process-restart", 100), using: signer)
            try check(next.sequence == 2 && next.sumMeanKcal == 800 && signer.count == 1, "separate process continues sequence")
            let transfer = try await wallet.exportTransfer()
            try Data(transfer.utf8).write(to: output.appendingPathComponent("transfer.json"), options: .atomic)
            let expected: [String: Any] = ["eventCount": 3, "sumMeanKcal": 800, "sumVarKcal": 8, "diagnostics": [String]()]
            try JSONSerialization.data(withJSONObject: expected, options: .sortedKeys).write(to: output.appendingPathComponent("expected.json"), options: .atomic)
            print("signed food separate-process restart: PASS (idempotent retry and next sequence)")
            return
        }
        let signer = TestSigner()
        let storage = FaultStore()
        var wallet = try GrainSignedFoodWallet(trustedRootPublicKey: signer.publicKey, persistence: storage)
        _ = try await wallet.initialize(using: signer)
        let first = try await wallet.record(food("meal-1", 700), using: signer)
        try check(first.sequence == 1 && first.sumMeanKcal == 700, "first durable intake")
        wallet = try GrainSignedFoodWallet(trustedRootPublicKey: signer.publicKey, persistence: storage)
        let calls = signer.count
        let repeated = try await wallet.record(food("meal-1", 700), using: signer)
        try check(repeated.status == "AlreadyCommitted" && signer.count == calls, "restart idempotency")

        storage.inject(offset: 1)
        try await storageFailure { try await wallet.record(food("meal-2"), using: signer) }
        try check(signer.count == calls, "failed prepare must not sign")
        let second = try await wallet.record(food("meal-2"), using: signer)
        try check(second.sequence == 2, "retry after failed preparation")

        storage.inject(offset: 2)
        try await storageFailure { try await wallet.record(food("meal-3"), using: signer) }
        let signedBeforeCrash = signer.last
        wallet = try GrainSignedFoodWallet(trustedRootPublicKey: signer.publicKey, persistence: storage)
        let third = try await wallet.record(food("meal-3"), using: signer)
        try check(third.sequence == 3 && signer.last == signedBeforeCrash, "commit failure resumes exact signed bytes")

        storage.inject(offset: 2, afterWrite: true)
        try await storageFailure { try await wallet.record(food("meal-4"), using: signer) }
        let afterCommitCalls = signer.count
        let fourth = try await wallet.record(food("meal-4"), using: signer)
        try check(fourth.status == "AlreadyCommitted" && signer.count == afterCommitCalls, "uncertain commit acknowledgement")

        storage.inject(offset: 1, afterWrite: true)
        try await storageFailure { try await wallet.record(food("meal-5"), using: signer) }
        try check(signer.count == afterCommitCalls, "uncertain prepare must not sign")
        let fifth = try await wallet.record(food("meal-5"), using: signer)
        try check(fifth.sequence == 5, "uncertain prepare retry")

        signer.failNext()
        do { _ = try await wallet.record(food("meal-6"), using: signer); throw SmokeError.assertion("signer failure missing") }
        catch GrainSignedFoodError.signerFailed {}
        let failedMessage = signer.last
        wallet = try GrainSignedFoodWallet(trustedRootPublicKey: signer.publicKey, persistence: storage)
        let sixth = try await wallet.record(food("meal-6"), using: signer)
        try check(sixth.sequence == 6 && signer.last == failedMessage, "signer retry reservation")

        storage.inject(offset: 1, failRead: true)
        try await storageFailure { try await wallet.record(food("meal-7"), using: signer) }
        do { _ = try await wallet.record(food("meal-7"), using: signer); throw SmokeError.assertion("writer not stopped") }
        catch GrainSignedFoodError.writerUnavailable {}
        storage.allowReads()
        wallet = try GrainSignedFoodWallet(trustedRootPublicKey: signer.publicKey, persistence: storage)
        let seventh = try await wallet.record(food("meal-7"), using: signer)
        try check(seventh.sequence == 7, "recover stopped writer from durable state")

        let concurrentWallet = wallet
        let sequences = try await withThrowingTaskGroup(of: UInt64.self) { group in
            for index in 0..<8 {
                group.addTask {
                    let receipt = try await concurrentWallet.record(food("parallel-\(index)"), using: signer)
                    return receipt.sequence!
                }
            }
            var values = Set<UInt64>()
            for try await sequence in group { values.insert(sequence) }
            return values
        }
        try check(sequences == Set(UInt64(8)...UInt64(15)), "actor serializes concurrent writes")

        // Real filesystem restart and handoff. Only synthetic food and public keys leave this process.
        let output = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("grain-signed-food-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let file = GrainFileSnapshotPersistence(fileURL: output.appendingPathComponent("private.snapshot"))
        let fileSigner = TestSigner(seed: 86)
        let fileWallet = try GrainSignedFoodWallet(trustedRootPublicKey: fileSigner.publicKey, persistence: file)
        _ = try await fileWallet.initialize(using: fileSigner)
        _ = try await fileWallet.record(food("confirmed-meal", 700), using: fileSigner)
        let reopened = try GrainSignedFoodWallet(trustedRootPublicKey: fileSigner.publicKey, persistence: file)
        let receipt = try await reopened.record(food("confirmed-meal", 700), using: fileSigner)
        try check(receipt.status == "AlreadyCommitted" && receipt.sumMeanKcal == 700, "file restore")
        let transfer = try await reopened.exportTransfer()
        try Data(transfer.utf8).write(to: output.appendingPathComponent("transfer.json"), options: .atomic)
        try Data(fileSigner.publicKey.base64EncodedString().utf8).write(to: output.appendingPathComponent("trusted-root.b64"), options: .atomic)
        let expected: [String: Any] = ["eventCount": 2, "sumMeanKcal": 700, "sumVarKcal": 4, "diagnostics": [String]()]
        try JSONSerialization.data(withJSONObject: expected, options: .sortedKeys).write(to: output.appendingPathComponent("expected.json"), options: .atomic)
        let reader = try GrainSignedFoodWallet(trustedRootPublicKey: fileSigner.publicKey, persistence: FaultStore())
        let imported = try await reader.importTransfer(transfer)
        try check(imported.sumMeanKcal == 700, "verified public import")
        do { _ = try await reader.record(food("viewer-write"), using: fileSigner); throw SmokeError.assertion("public import writable") }
        catch GrainSignedFoodError.rejected(let diagnostics) { try check(diagnostics == ["SDK_ERR_SIGNED_FOOD_READ_ONLY"], "read-only diagnostic") }
        print("signed food Swift smoke: PASS (durability faults, restart, idempotency, concurrency, file handoff)")
    }
}
