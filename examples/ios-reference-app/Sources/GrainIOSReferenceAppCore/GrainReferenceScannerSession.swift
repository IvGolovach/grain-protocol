import Foundation
import GrainIOSScanner

@MainActor
public final class GrainReferenceScannerSession: ObservableObject {
    @Published public private(set) var model: ScannerShellModel?
    @Published public private(set) var launchDiagnostic: String?

    public let configuration: GrainReferenceAppConfiguration
    private var started = false

    public init(configuration: GrainReferenceAppConfiguration) {
        self.configuration = configuration
    }

    public func start() {
        guard !started else {
            return
        }
        started = true

        do {
            let scannerModel = try GrainReferenceScannerFactory.makeModel(configuration: configuration)
            scannerModel.restorePersistedSnapshot()
            scannerModel.prepareLocalIdentity(rootLabel: "ios-reference", deviceLabel: "phone")
            model = scannerModel
            launchDiagnostic = nil
        } catch {
            launchDiagnostic = "SDK_ERR_IOS_REFERENCE_START_FAILED"
            model = nil
        }
    }

    public func restorePersistedSnapshot() {
        model?.restorePersistedSnapshot()
    }

    public func loadDemoScanAndPreview() {
        guard let qrString = configuration.demoQRCode, !qrString.isEmpty else {
            launchDiagnostic = "SDK_ERR_IOS_REFERENCE_DEMO_QR_MISSING"
            return
        }

        model?.receiveCameraPayload(
            CameraScanPayload(qrString: qrString, source: .injected)
        )
        model?.preview()
        launchDiagnostic = nil
    }
}
