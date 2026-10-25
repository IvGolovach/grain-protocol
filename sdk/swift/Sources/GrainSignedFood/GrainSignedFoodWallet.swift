import Foundation
import GrainClientFFI
import GrainClientIOSAdapters

/// App-owned Ed25519 signer. Never export its private key to the journal.
/// Signing is synchronous so an actor cannot interleave another write while signing.
public protocol GrainFoodSigner: Sendable {
    var publicKey: Data { get }
    func signPreparedMessage(_ message: Data) throws -> Data
}

public enum GrainSignedFoodError: Error, Equatable, Sendable {
    case rejected([String])
    case persistenceFailed
    case signerFailed
    case writerUnavailable
}

public enum GrainSignedFoodSource: String, Sendable {
    case estimated
    case measured
}

/// Construct only after the application confirms the food input with its user.
/// A user signature authenticates authorship, not nutritional truth or issuer attestation.
public struct GrainConfirmedFood: Sendable {
    public let operationId: String
    public let source: GrainSignedFoodSource
    public let meanKcal: Int64
    public let varianceKcal: Int64

    public init(operationId: String, source: GrainSignedFoodSource, meanKcal: Int64, varianceKcal: Int64) {
        self.operationId = operationId
        self.source = source
        self.meanKcal = meanKcal
        self.varianceKcal = varianceKcal
    }
}

/// Durable commit receipt; contains no signing request, snapshot or private key.
public struct GrainSignedFoodReceipt: Sendable {
    public let status: String
    public let sequence: UInt64?
    public let eventCount: UInt64
    public let sumMeanKcal: Int64?
    public let sumVarianceKcal: Int64?
    public let diagnostics: [String]

    fileprivate init(_ result: FfiSignedFoodResult) {
        status = result.status
        sequence = result.seq
        eventCount = result.eventCount
        sumMeanKcal = result.sumMeanKcal
        sumVarianceKcal = result.sumVarKcal
        diagnostics = result.diag
    }
}

/// One writer per persistence location. Apps sharing a file across processes must
/// provide external ownership/locking. Storage must atomically replace snapshots.
/// The trust root comes from app trust policy, never from an untrusted import file.
public actor GrainSignedFoodWallet {
    private let persistence: any GrainSnapshotPersistence
    private let trustedRootPubB64: String
    private var journal: GrainSignedFoodJournal?
    private var hasDurableSnapshot = false

    public init(trustedRootPublicKey: Data, persistence: any GrainSnapshotPersistence) throws {
        guard trustedRootPublicKey.count == 32 else {
            throw GrainSignedFoodError.rejected(["SDK_ERR_SIGNED_FOOD_TRUST"])
        }
        self.persistence = persistence
        trustedRootPubB64 = trustedRootPublicKey.base64EncodedString()
        let loaded = GrainSignedFoodJournal()
        do {
            if let saved = try persistence.loadSnapshotB64() {
                let result = loaded.restoreSnapshot(snapshotB64: saved, trustedRootPubB64: trustedRootPubB64)
                guard result.status == "Restored" else { throw GrainSignedFoodError.rejected(result.diag) }
                hasDurableSnapshot = true
            }
        } catch let error as GrainSignedFoodError {
            throw error
        } catch {
            throw GrainSignedFoodError.persistenceFailed
        }
        journal = loaded
    }

    public func initialize(using signer: any GrainFoodSigner) throws -> GrainSignedFoodReceipt {
        guard signer.publicKey.base64EncodedString() == trustedRootPubB64 else {
            throw GrainSignedFoodError.rejected(["SDK_ERR_SIGNED_FOOD_TRUST"])
        }
        return try finish(writer().initialize(rootPubB64: trustedRootPubB64), using: signer)
    }

    public func record(_ food: GrainConfirmedFood, using signer: any GrainFoodSigner) throws -> GrainSignedFoodReceipt {
        let prepared = try writer().prepareIntake(
            authorPubB64: signer.publicKey.base64EncodedString(), operationId: food.operationId,
            sourceClass: food.source.rawValue, meanKcal: food.meanKcal, varKcal: food.varianceKcal
        )
        return try finish(prepared, using: signer)
    }

    public func grantDevice(publicKey: Data, operationId: String, using rootSigner: any GrainFoodSigner) throws -> GrainSignedFoodReceipt {
        try requireRoot(rootSigner)
        return try finish(writer().prepareGrant(operationId: operationId, devicePubB64: publicKey.base64EncodedString()), using: rootSigner)
    }

    public func revokeDevice(publicKey: Data, operationId: String, using rootSigner: any GrainFoodSigner) throws -> GrainSignedFoodReceipt {
        try requireRoot(rootSigner)
        return try finish(writer().prepareRevoke(operationId: operationId, devicePubB64: publicKey.base64EncodedString()), using: rootSigner)
    }

    /// Public imports on a fresh wallet are read-only: they carry no private sequence reservations.
    public func importTransfer(_ transfer: String) throws -> GrainSignedFoodReceipt {
        let result = try writer().importTransfer(transferJson: transfer, trustedRootPubB64: trustedRootPubB64)
        guard result.status == "Imported" else { throw GrainSignedFoodError.rejected(result.diag) }
        try persist(result)
        return GrainSignedFoodReceipt(result)
    }

    public func restoreBackup(_ snapshotB64: String) throws -> GrainSignedFoodReceipt {
        let result = try writer().restoreSnapshot(snapshotB64: snapshotB64, trustedRootPubB64: trustedRootPubB64)
        guard result.status == "Restored" else { throw GrainSignedFoodError.rejected(result.diag) }
        try persist(result)
        return GrainSignedFoodReceipt(result)
    }

    /// Sensitive food data. The app decides how to protect and share this file.
    public func exportTransfer() throws -> String {
        let result = try writer().exportTransfer()
        guard result.status == "Exported", let transfer = result.transferJson else {
            throw GrainSignedFoodError.rejected(result.diag)
        }
        return transfer
    }

    private func requireRoot(_ signer: any GrainFoodSigner) throws {
        guard signer.publicKey.base64EncodedString() == trustedRootPubB64 else {
            throw GrainSignedFoodError.rejected(["SDK_ERR_SIGNED_FOOD_TRUST"])
        }
    }

    private func writer() throws -> GrainSignedFoodJournal {
        guard let journal else { throw GrainSignedFoodError.writerUnavailable }
        return journal
    }

    private func finish(_ prepared: FfiSignedFoodResult, using signer: any GrainFoodSigner) throws -> GrainSignedFoodReceipt {
        if prepared.status == "AlreadyCommitted" { return GrainSignedFoodReceipt(prepared) }
        guard prepared.status == "Prepared", let operation = prepared.operationId,
              let encoded = prepared.signingBytesB64, let message = Data(base64Encoded: encoded) else {
            throw GrainSignedFoodError.rejected(prepared.diag)
        }
        // A signature may escape the process. Save its exact bytes and sequence first.
        try persist(prepared)
        let signature: Data
        do { signature = try signer.signPreparedMessage(message) }
        catch { throw GrainSignedFoodError.signerFailed }
        let committed = try writer().commitSignature(operationId: operation, signatureB64: signature.base64EncodedString())
        guard committed.status == "Committed" else { throw GrainSignedFoodError.rejected(committed.diag) }
        try persist(committed)
        return GrainSignedFoodReceipt(committed)
    }

    private func persist(_ result: FfiSignedFoodResult) throws {
        guard let snapshot = result.snapshotB64 else {
            journal = nil
            throw GrainSignedFoodError.writerUnavailable
        }
        do {
            try persistence.saveSnapshotB64(snapshot)
            hasDurableSnapshot = true
        }
        catch {
            // Save may have succeeded before its acknowledgement failed. Re-read durable
            // state instead of rolling back a counter or assuming the old state survived.
            journal = nil
            do {
                let saved = try persistence.loadSnapshotB64()
                let loaded = GrainSignedFoodJournal()
                if let saved {
                    if loaded.restoreSnapshot(snapshotB64: saved, trustedRootPubB64: trustedRootPubB64).status == "Restored" {
                        journal = loaded
                        hasDurableSnapshot = true
                    }
                } else if !hasDurableSnapshot {
                    // No successful save means no signer could have received a
                    // reservation from this wallet. A confirmed empty store is retryable.
                    journal = loaded
                }
            } catch {
                // Failed reads leave the writer unavailable.
            }
            throw GrainSignedFoodError.persistenceFailed
        }
    }
}
