import SwiftUI
import GrainIOSReferenceAppCore

private let referenceAppConfiguration = Result {
    try GrainReferenceAppResources.bundled()
}

@main
struct GrainIOSReferenceApp: App {
    var body: some Scene {
        WindowGroup {
            switch referenceAppConfiguration {
            case let .success(configuration):
                GrainReferenceScannerRootView(configuration: configuration)
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40, weight: .regular))
                    Text("SDK_ERR_IOS_REFERENCE_CONFIG")
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
}
