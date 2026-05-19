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

public enum FoodAnalysisSource: Equatable, Sendable {
    case example(FoodCaptureExample)
    case photo(id: String)
    case transientPhoto(id: String, byteCount: Int)
}

public struct FoodAnalysisOperation: Equatable, Sendable {
    public var id: UUID
    public var source: FoodAnalysisSource
    public var startedAt: Date

    public init(id: UUID = UUID(), source: FoodAnalysisSource, startedAt: Date = Date()) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
    }
}

public enum FoodAnalysisFailureCode: Equatable, Sendable {
    case invalidPayload
    case invalidResponse
    case httpStatus(Int)
    case unsafeCandidate
    case network
    case unknown
}

public struct FoodAnalysisFailure: Equatable, Sendable {
    public var code: FoodAnalysisFailureCode
    public var message: String

    public init(code: FoodAnalysisFailureCode, message: String) {
        self.code = code
        self.message = message
    }
}

public enum FoodAnalysisState: Equatable, Sendable {
    case idle
    case analyzing(FoodAnalysisOperation)
    case slow(FoodAnalysisOperation)
    case failed(FoodAnalysisFailure)
    case draftReady
    case blockedPrivacy

    public var isAnalyzing: Bool {
        switch self {
        case .analyzing, .slow:
            return true
        case .idle, .failed, .draftReady, .blockedPrivacy:
            return false
        }
    }

    public var isSlow: Bool {
        if case .slow = self {
            return true
        }
        return false
    }

    public var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    public var statusText: String {
        switch self {
        case .idle:
            return "No active analysis"
        case .analyzing:
            return "Looking for food"
        case .slow:
            return "Still analyzing photo"
        case .failed:
            return "Couldn’t analyze photo"
        case .draftReady:
            return "Draft ready"
        case .blockedPrivacy:
            return "AI photo analysis disabled"
        }
    }

    public var errorMessage: String? {
        if case let .failed(failure) = self {
            return failure.message
        }
        return nil
    }
}

@MainActor
public final class FoodWalletStore: ObservableObject {
    private static let defaultSlowAnalysisThresholdNanoseconds: UInt64 = 8_000_000_000

    @Published public private(set) var currentCandidate: FoodAnalysisCandidate?
    @Published public private(set) var currentDraft: FoodIntakeDraft?
    @Published public private(set) var analysisState: FoodAnalysisState
    @Published public private(set) var entries: [FoodIntakeEntry]
    @Published public private(set) var safeSummary: SafeFoodSummary
    @Published public var selectedExample: FoodCaptureExample
    @Published public var subscription: SubscriptionState
    @Published public var privacy: PrivacyConsentState

    private let analysisClient: any FoodAnalysisClient
    private let slowAnalysisThresholdNanoseconds: UInt64
    private var slowAnalysisTask: Task<Void, Never>?
    private var wallet: GrainFoodWallet

    public init(
        analysisClient: any FoodAnalysisClient = MockFoodAnalysisClient(),
        wallet: GrainFoodWallet = GrainFoodWallet(),
        subscription: SubscriptionState = .free,
        privacy: PrivacyConsentState = .notRequested,
        slowAnalysisThresholdNanoseconds: UInt64 = 8_000_000_000
    ) {
        self.analysisClient = analysisClient
        self.slowAnalysisThresholdNanoseconds = slowAnalysisThresholdNanoseconds
        self.wallet = wallet
        self.analysisState = .idle
        self.entries = []
        self.safeSummary = wallet.exportSafeSummary()
        self.selectedExample = .fujiApple
        self.subscription = subscription
        self.privacy = privacy
    }

    public var todayTotalLabel: String {
        let selected = todayEntries
        if selected.isEmpty {
            return "No meals saved yet"
        }
        let mean = selected.reduce(Int64(0)) { $0 + $1.meal.kcal }
        let variance = selected.reduce(Int64(0)) { $0 + $1.meal.varianceKcal }
        if variance == 0 {
            return "\(mean) kcal"
        }
        return "\(max(0, mean - variance))-\(mean + variance) kcal"
    }

    public var todayEntries: [FoodIntakeEntry] {
        entries.filter { Calendar.autoupdatingCurrent.isDateInToday($0.confirmedAt) }
    }

    public var hasDraft: Bool {
        currentDraft != nil && currentCandidate != nil
    }

    public var canStartAnalysis: Bool {
        !analysisState.isAnalyzing && privacy != .denied
    }

    public var canSaveDraft: Bool {
        analysisState == .draftReady && hasDraft
    }

    public var canDiscardDraft: Bool {
        hasDraft || analysisState.isFailed || analysisState == .blockedPrivacy
    }

    public func grantAIConsent() {
        privacy = .granted
    }

    public func chooseExample(_ example: FoodCaptureExample) {
        selectedExample = example
    }

    public func analyzeSelectedExample() async {
        guard preparePrivacyForAnalysis() else {
            return
        }
        await analyze(example: selectedExample)
    }

    public func analyze(example: FoodCaptureExample) async {
        guard preparePrivacyForAnalysis() else {
            return
        }
        let operation = beginAnalysis(source: .example(example))
        do {
            let candidate = try await analysisClient.estimate(example: example)
            apply(candidate: candidate, for: operation)
        } catch {
            failAnalysis(error, for: operation)
        }
    }

    public func analyze(photo: CapturedMealPhoto) async {
        guard preparePrivacyForAnalysis() else {
            return
        }

        let operation = beginAnalysis(source: .photo(id: photo.id))
        do {
            let candidate = try await analysisClient.estimate(photo: photo)
            apply(candidate: candidate, for: operation)
        } catch {
            failAnalysis(error, for: operation)
        }
    }

    public func analyze(photoPayload: TransientMealPhotoPayload) async {
        guard preparePrivacyForAnalysis() else {
            return
        }

        let operation = beginAnalysis(source: .transientPhoto(
            id: photoPayload.photo.id,
            byteCount: photoPayload.byteCount
        ))
        do {
            let candidate = try await analysisClient.estimate(photoPayload: photoPayload)
            apply(candidate: candidate, for: operation)
        } catch {
            failAnalysis(error, for: operation)
        }
    }

    public func cancelAnalysis() {
        slowAnalysisTask?.cancel()
        slowAnalysisTask = nil
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
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
        analysisState = .idle
    }

    public func discardDraft() {
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
    }

    public func resetLocalData() {
        slowAnalysisTask?.cancel()
        slowAnalysisTask = nil
        wallet = GrainFoodWallet()
        entries = []
        currentCandidate = nil
        currentDraft = nil
        analysisState = .idle
        safeSummary = wallet.exportSafeSummary()
    }

    public func runDeviceSmoke() async -> FoodWalletDeviceSmokeResult {
        resetLocalData()

        await analyze(photo: .uiTestFujiApple)
        guard currentCandidate?.primaryLabel == "Fuji apple", currentDraft != nil else {
            return smokeFailure("photo apple draft was not created")
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

    private func preparePrivacyForAnalysis() -> Bool {
        if privacy == .denied {
            slowAnalysisTask?.cancel()
            slowAnalysisTask = nil
            currentCandidate = nil
            currentDraft = nil
            analysisState = .blockedPrivacy
            return false
        }
        if privacy == .notRequested {
            grantAIConsent()
        }
        return true
    }

    private func beginAnalysis(source: FoodAnalysisSource) -> FoodAnalysisOperation {
        slowAnalysisTask?.cancel()
        currentCandidate = nil
        currentDraft = nil

        let operation = FoodAnalysisOperation(source: source)
        analysisState = .analyzing(operation)
        scheduleSlowState(for: operation)
        return operation
    }

    private func scheduleSlowState(for operation: FoodAnalysisOperation) {
        let threshold = slowAnalysisThresholdNanoseconds
        slowAnalysisTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: threshold)
            } catch {
                return
            }
            await MainActor.run {
                guard let self, self.analysisState == .analyzing(operation) else {
                    return
                }
                self.analysisState = .slow(operation)
            }
        }
    }

    private func apply(candidate: FoodAnalysisCandidate, for operation: FoodAnalysisOperation) {
        guard isCurrent(operation: operation) else {
            return
        }
        slowAnalysisTask?.cancel()
        slowAnalysisTask = nil
        let draft = wallet.makeEstimatedDraft(meal: candidate.mealEstimate())
        currentCandidate = candidate
        currentDraft = draft
        analysisState = .draftReady
    }

    private func failAnalysis(_ error: Error, for operation: FoodAnalysisOperation) {
        guard isCurrent(operation: operation) else {
            return
        }
        slowAnalysisTask?.cancel()
        slowAnalysisTask = nil
        currentCandidate = nil
        currentDraft = nil
        analysisState = .failed(FoodAnalysisFailure(
            code: FoodWalletStore.failureCode(for: error),
            message: "The analysis service did not return a usable food estimate. Try another photo or enter this meal manually."
        ))
    }

    private func isCurrent(operation: FoodAnalysisOperation) -> Bool {
        switch analysisState {
        case let .analyzing(current), let .slow(current):
            return current.id == operation.id
        case .idle, .failed, .draftReady, .blockedPrivacy:
            return false
        }
    }

    private static func failureCode(for error: Error) -> FoodAnalysisFailureCode {
        guard let brokerError = error as? FoodAnalysisBrokerClientError else {
            return .unknown
        }

        switch brokerError {
        case .invalidPayload:
            return .invalidPayload
        case .invalidResponse:
            return .invalidResponse
        case let .httpStatus(status):
            return .httpStatus(status)
        case .unsafeCandidate:
            return .unsafeCandidate
        }
    }
}
