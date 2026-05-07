import Foundation
import SwiftUI

public struct ScannerView: View {
    @StateObject private var model: ScannerShellModel
    private let loadDemoScan: (() -> Void)?

    public init(model: ScannerShellModel, loadDemoScan: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: model)
        self.loadDemoScan = loadDemoScan
    }

    public var body: some View {
        Form {
            Section("Scan or paste") {
                TextField(
                    "Paste GR1 string",
                    text: Binding(
                        get: { model.state.qrString },
                        set: { model.updateQrString($0) }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...8)

                LabeledContent("Input", value: inputSourceLabel)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        scanActionButtons
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        scanActionButtons
                    }
                }
                .buttonStyle(.bordered)
            }

            Section("Preview") {
                LabeledContent("Status", value: model.state.previewStatus?.rawValue ?? "Waiting")
                LabeledContent("Accept enabled", value: model.state.canAccept ? "Yes" : "No")
            }

            Section("Accept and save") {
                if let lifecycleStatus = model.state.lifecycleStatus {
                    LabeledContent("Local identity", value: lifecycleStatus)
                    LabeledContent("Devices", value: "\(model.state.deviceCount)")
                    LabeledContent("Lifecycle events", value: "\(model.state.lifecycleEventCount)")
                }

                if let acceptStatus = model.state.acceptStatus {
                    LabeledContent("Last accept", value: acceptStatus.rawValue)
                }

                LabeledContent("Saved", value: "\(model.state.acceptedCount)")

                ForEach(model.state.acceptedScans) { scan in
                    Text(scan.id)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }

                if let snapshotStatus = model.state.snapshotStatus {
                    LabeledContent("Snapshot", value: snapshotStatus)
                }

                Button {
                    model.accept()
                } label: {
                    Label("Accept", systemImage: "checkmark.seal")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.state.canAccept)
            }

            Section("Export and debug") {
                if let exportStatus = model.state.exportStatus {
                    LabeledContent("Export", value: exportStatus)
                    LabeledContent("Exported scans", value: "\(model.state.exportAcceptedCount)")
                    LabeledContent("Exported devices", value: "\(model.state.exportDeviceCount)")
                    LabeledContent("Exported events", value: "\(model.state.exportLifecycleEventCount)")
                }

                LabeledContent("Diagnostics", value: "\(model.state.diagnostics.count)")

                ForEach(model.state.diagnostics, id: \.self) { diagnostic in
                    Text(diagnostic)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        debugActionButtons
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        debugActionButtons
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var scanActionButtons: some View {
        if let loadDemoScan {
            Button {
                loadDemoScan()
            } label: {
                Label("Demo QR", systemImage: "qrcode.viewfinder")
            }
        }

        Button {
            model.preview()
        } label: {
            Label("Preview", systemImage: "doc.text.magnifyingglass")
        }
        .disabled(!hasScanInput)

        Button(role: .destructive) {
            model.clearScanInput()
        } label: {
            Label("Clear", systemImage: "xmark.circle")
        }
        .disabled(!hasScanInput)
    }

    @ViewBuilder
    private var debugActionButtons: some View {
        Button {
            model.refreshAcceptedScans()
        } label: {
            Label("Refresh saved", systemImage: "list.bullet")
        }

        Button {
            _ = model.exportDebugSummary()
        } label: {
            Label("Export counts", systemImage: "square.and.arrow.up")
        }

        Button {
            model.restorePersistedSnapshot()
        } label: {
            Label("Restore", systemImage: "arrow.clockwise")
        }
    }

    private var hasScanInput: Bool {
        !model.state.qrString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inputSourceLabel: String {
        switch model.state.scanSource {
        case .camera:
            return "Camera"
        case .injected:
            return "Demo QR"
        case nil:
            return hasScanInput ? "Manual paste" : "Empty"
        }
    }
}
