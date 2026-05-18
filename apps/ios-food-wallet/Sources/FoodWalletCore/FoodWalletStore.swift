import Combine
import Foundation
import GrainFoodWallet

public struct FoodWalletDeviceSmokeResult: Equatable, Sendable {
    public let passed: Bool
    public let entryCount: Int
    public let totalKcal: Int64
    public let reason: String

    public init(passed: Bool, entryCount: Int, totalKcal: Int64, reason: String) {
        self.passed = passed
        self.entryCount = entryCount
        self.totalKcal = totalKcal
        self.reason = reason
    }
}

@MainActor
public final class FoodWalletStore: ObservableObject {
    @Published public private(set) var currentCandidate: FoodAnalysisCandidate?
    @Published public private(set) var currentDraft: FoodIntakeDraft?
    @Published public private(set) var entries: [FoodIntakeEntry]
    @Published public private(set) var safeSummary: SafeFoodSummary
    @Published public var selectedExample: FoodCaptureExample
    @Published public var subscription: SubscriptionState
    @Published public var privacy: PrivacyConsentState

    private let analysisClient: any FoodAnalysisClient
    private var wallet: GrainFoodWallet

    public init(
        analysisClient: any FoodAnalysisClient = MockFoodAnalysisClient(),
        wallet: GrainFoodWallet = GrainFoodWallet(),
        subscription: SubscriptionState = .free,
        privacy: PrivacyConsentState = .notRequested
    ) {
        self.analysisClient = analysisClient
        self.wallet = wallet
        self.entries = []
        self.safeSummary = wallet.exportSafeSummary()
        self.selectedExample = .fujiApple
        self.subscription = subscription
        self.privacy = privacy
    }

    public var todayTotalLabel: String {
        if entries.isEmpty {
            return "No meals saved yet"
        }
        let totals = safeSummary.totals
        let variance = totals.sumVarianceKcal
        if variance == 0 {
            return "\(totals.sumMeanKcal) kcal"
        }
        return "\(max(0, totals.sumMeanKcal - variance))-\(totals.sumMeanKcal + variance) kcal"
    }

    public var hasDraft: Bool {
        currentDraft != nil && currentCandidate != nil
    }

    public func grantAIConsent() {
        privacy = .granted
    }

    public func chooseExample(_ example: FoodCaptureExample) {
        selectedExample = example
    }

    public func analyzeSelectedExample() async {
        if privacy == .denied {
            return
        }
        if privacy == .notRequested {
            grantAIConsent()
        }
        await analyze(example: selectedExample)
    }

    public func analyze(example: FoodCaptureExample) async {
        do {
            let candidate = try await analysisClient.estimate(example: example)
            let draft = wallet.makeEstimatedDraft(meal: candidate.mealEstimate())
            currentCandidate = candidate
            currentDraft = draft
        } catch {
            currentCandidate = nil
            currentDraft = nil
        }
    }

    public func toggleAssumption(id: String) {
        guard var candidate = currentCandidate else {
            return
        }
        candidate.assumptions = candidate.assumptions.map { assumption in
            guard assumption.id == id else {
                return assumption
            }
            var copy = assumption
            copy.isEnabled.toggle()
            return copy
        }
        currentCandidate = candidate
        currentDraft = wallet.makeEstimatedDraft(meal: candidate.mealEstimate())
    }

    public func confirmDraft() {
        guard let draft = currentDraft else {
            return
        }
        let entry = wallet.confirmDraft(draft)
        entries.insert(entry, at: 0)
        safeSummary = wallet.exportSafeSummary()
        currentCandidate = nil
        currentDraft = nil
    }

    public func discardDraft() {
        currentCandidate = nil
        currentDraft = nil
    }

    public func resetLocalData() {
        wallet = GrainFoodWallet()
        entries = []
        currentCandidate = nil
        currentDraft = nil
        safeSummary = wallet.exportSafeSummary()
    }

    public func runDeviceSmoke() async -> FoodWalletDeviceSmokeResult {
        resetLocalData()

        await analyze(example: .fujiApple)
        guard currentCandidate?.primaryLabel == "Fuji apple", currentDraft != nil else {
            return smokeFailure("apple draft was not created")
        }
        confirmDraft()

        await analyze(example: .mushroomRisotto)
        guard currentCandidate?.primaryLabel == "Mushroom risotto", currentDraft != nil else {
            return smokeFailure("risotto draft was not created")
        }
        toggleAssumption(id: "butter-oil")
        confirmDraft()

        guard entries.count == 2 else {
            return smokeFailure("expected two confirmed entries, got \(entries.count)")
        }
        guard safeSummary.totals.entryCount == 2 else {
            return smokeFailure("expected two safe summary entries, got \(safeSummary.totals.entryCount)")
        }

        let summary = String(describing: safeSummary)
        let forbidden = ["rawPhoto", "photoBytes", "COSE", "CBOR", "snapshot", "privateKey", "trustPub", "GR1"]
        for token in forbidden where summary.localizedCaseInsensitiveContains(token) {
            return smokeFailure("safe summary leaked \(token)")
        }

        return FoodWalletDeviceSmokeResult(
            passed: true,
            entryCount: entries.count,
            totalKcal: safeSummary.totals.sumMeanKcal,
            reason: "ok"
        )
    }

    private func smokeFailure(_ reason: String) -> FoodWalletDeviceSmokeResult {
        FoodWalletDeviceSmokeResult(
            passed: false,
            entryCount: entries.count,
            totalKcal: safeSummary.totals.sumMeanKcal,
            reason: reason
        )
    }
}
