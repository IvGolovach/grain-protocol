import SwiftUI
import GrainIOSScanner

public struct GrainReferenceScannerRootView: View {
    @StateObject private var session: GrainReferenceScannerSession

    public init(configuration: GrainReferenceAppConfiguration) {
        _session = StateObject(wrappedValue: GrainReferenceScannerSession(configuration: configuration))
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Grain")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            session.restorePersistedSnapshot()
                        } label: {
                            Label("Restore", systemImage: "arrow.clockwise")
                        }
                        .disabled(session.model == nil)

                        Button {
                            session.loadDemoScanAndPreview()
                        } label: {
                            Label("Demo QR", systemImage: "qrcode.viewfinder")
                        }
                        .disabled(session.model == nil || session.configuration.demoQRCode == nil)
                    }
                }
        }
        .task {
            session.start()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model = session.model {
            ScannerView(model: model)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 44, weight: .regular))
                Text(session.launchDiagnostic ?? "SDK_ERR_IOS_REFERENCE_LOADING")
                    .font(.footnote.monospaced())
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}
