import Combine
import Foundation
import GrainFoodWallet

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
    private let wallet: GrainFoodWallet

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
        if privacy != .granted {
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
        entries = []
        currentCandidate = nil
        currentDraft = nil
        safeSummary = wallet.exportSafeSummary()
    }
}
