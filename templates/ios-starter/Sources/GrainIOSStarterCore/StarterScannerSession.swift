import Foundation
import GrainIOSScanner
import SwiftUI

@MainActor
public final class StarterScannerSession: ObservableObject {
    @Published public private(set) var model: ScannerShellModel?
    @Published public private(set) var launchDiagnostic: String?

    public init() {}

    public func start() {
        guard model == nil else {
            return
        }
        do {
            let starterModel = try ScannerShellModel(
                keychainBackedTrustAnchorBundleURL: StarterResources.trustAnchorBundleURL,
                initialTrustAnchorID: StarterResources.trustAnchorID
            )
            starterModel.restorePersistedSnapshot()
            starterModel.prepareLocalIdentity(rootLabel: "ios-starter", deviceLabel: "phone")
            model = starterModel
            launchDiagnostic = nil
        } catch {
            launchDiagnostic = "SDK_ERR_IOS_STARTER_START_FAILED"
        }
    }

    public func paste(_ qrString: String) {
        model?.updateQrString(qrString)
    }

    public func loadBundledSample() {
        model?.updateQrString(StarterResources.sampleQrString)
    }

    public func preview() {
        model?.preview()
    }

    public func acceptVerifiedPreview() {
        model?.accept()
    }

    public func restore() {
        model?.restorePersistedSnapshot()
    }

    public func acceptedScanIDs() -> [String] {
        model?.state.acceptedScans.map(\.id) ?? []
    }

    public func exportForShare() {
        _ = model?.exportSyncBundleForShare()
    }
}

public struct StarterScannerView: View {
    @StateObject private var session: StarterScannerSession
    @State private var pastedScan = ""

    public init(session: StarterScannerSession) {
        _session = StateObject(wrappedValue: session)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $pastedScan)
                .frame(minHeight: 120)
                .onChange(of: pastedScan) { _, value in
                    session.paste(value)
                }
            HStack {
                Button("Sample") { session.loadBundledSample() }
                Button("Restore") { session.restore() }
                Button("Preview") { session.preview() }
                Button("Accept") { session.acceptVerifiedPreview() }
                    .disabled(!(session.model?.state.canAccept ?? false))
                Button("Export") { session.exportForShare() }
            }
            Text(statusLine)
            ForEach(session.acceptedScanIDs(), id: \.self) { scanID in
                Text(scanID)
            }
        }
        .padding()
        .onAppear {
            session.start()
        }
    }

    private var statusLine: String {
        guard let state = session.model?.state else {
            return session.launchDiagnostic ?? "Starting"
        }
        return [
            state.previewStatus.map { "Preview: \($0.rawValue)" },
            state.acceptStatus.map { "Accept: \($0.rawValue)" },
            state.snapshotStatus.map { "Snapshot: \($0)" },
            state.exportStatus.map { "Export: \($0)" },
            "Saved: \(state.acceptedCount)",
        ].compactMap { $0 }.joined(separator: " | ")
    }
}
