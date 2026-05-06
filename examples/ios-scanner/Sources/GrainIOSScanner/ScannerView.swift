import SwiftUI

public struct ScannerView: View {
    @StateObject private var model: ScannerShellModel

    public init(model: ScannerShellModel) {
        _model = StateObject(wrappedValue: model)
    }

    public var body: some View {
        Form {
            Section("Scan") {
                TextField(
                    "GR1 string",
                    text: Binding(
                        get: { model.state.qrString },
                        set: { model.updateQrString($0) }
                    ),
                    axis: .vertical
                )
                .lineLimit(3...8)

                TextField(
                    "Trust anchor ID",
                    text: Binding(
                        get: { model.state.trustAnchorID },
                        set: { model.updateTrustAnchorID($0) }
                    )
                )
            }

            Section("Result") {
                if let lifecycleStatus = model.state.lifecycleStatus {
                    LabeledContent("Lifecycle", value: lifecycleStatus)
                    LabeledContent("Devices", value: "\(model.state.deviceCount)")
                    LabeledContent("Lifecycle events", value: "\(model.state.lifecycleEventCount)")
                }

                if let previewStatus = model.state.previewStatus {
                    LabeledContent("Preview", value: previewStatus.rawValue)
                }

                if let acceptStatus = model.state.acceptStatus {
                    LabeledContent("Accept", value: acceptStatus.rawValue)
                }

                if let scanSource = model.state.scanSource {
                    LabeledContent("Source", value: scanSource.rawValue)
                }

                if let acceptedScanID = model.state.acceptedScanID {
                    Text(acceptedScanID)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
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

                if let exportStatus = model.state.exportStatus {
                    LabeledContent("Export", value: exportStatus)
                    LabeledContent("Exported scans", value: "\(model.state.exportAcceptedCount)")
                    LabeledContent("Exported devices", value: "\(model.state.exportDeviceCount)")
                    LabeledContent("Exported events", value: "\(model.state.exportLifecycleEventCount)")
                }

                ForEach(model.state.diagnostics, id: \.self) { diagnostic in
                    Text(diagnostic)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section {
                Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Button("Prepare") {
                            model.prepareLocalIdentity()
                        }

                        Button("Preview") {
                            model.preview()
                        }

                        Button("Accept") {
                            model.accept()
                        }
                        .disabled(!model.state.canAccept)
                    }

                    GridRow {
                        Button("List") {
                            model.refreshAcceptedScans()
                        }

                        Button("Export") {
                            _ = model.exportSyncBundleForShare()
                        }

                        Button("Restore") {
                            model.restorePersistedSnapshot()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}
