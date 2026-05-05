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

                if let acceptedScanID = model.state.acceptedScanID {
                    Text(acceptedScanID)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }

                LabeledContent("Saved", value: "\(model.state.acceptedCount)")

                if let snapshotStatus = model.state.snapshotStatus {
                    LabeledContent("Snapshot", value: snapshotStatus)
                }

                ForEach(model.state.diagnostics, id: \.self) { diagnostic in
                    Text(diagnostic)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }

            Section {
                HStack {
                    Button("Prepare device") {
                        model.prepareLocalIdentity()
                    }

                    Button("Preview") {
                        model.preview()
                    }

                    Button("Accept") {
                        model.accept()
                    }
                    .disabled(!model.state.canAccept)

                    Button("Restore") {
                        model.restorePersistedSnapshot()
                    }
                }
            }
        }
    }
}
