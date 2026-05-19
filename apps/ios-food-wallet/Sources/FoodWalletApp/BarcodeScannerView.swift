import SwiftUI

#if os(iOS)
import VisionKit
import UIKit
#endif

@MainActor
enum BarcodeScannerAvailability {
    static var canUseCameraScanner: Bool {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        }
        return false
        #else
        return false
        #endif
    }
}

struct BarcodeScannerView: View {
    var onBarcode: (String) -> Void

    var body: some View {
        #if os(iOS)
        if #available(iOS 16.0, *), BarcodeScannerAvailability.canUseCameraScanner {
            VisionKitBarcodeScannerView(onBarcode: onBarcode)
                .accessibilityIdentifier("BarcodeScannerCameraView")
        } else {
            BarcodeScannerUnavailableView()
        }
        #else
        BarcodeScannerUnavailableView()
        #endif
    }
}

private struct BarcodeScannerUnavailableView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "barcode.viewfinder")
                .font(.largeTitle)
            Text("Scanner unavailable")
                .font(.headline)
            Text("Enter the barcode below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .accessibilityIdentifier("BarcodeScannerUnavailableView")
    }
}

#if os(iOS)
@available(iOS 16.0, *)
private struct VisionKitBarcodeScannerView: UIViewControllerRepresentable {
    var onBarcode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce, .code128]),
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        guard uiViewController.isScanning == false else {
            return
        }
        try? uiViewController.startScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private var didEmit = false
        private let onBarcode: (String) -> Void

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emitFirstBarcode(from: addedItems, dataScanner: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            emitFirstBarcode(from: [item], dataScanner: dataScanner)
        }

        private func emitFirstBarcode(from items: [RecognizedItem], dataScanner: DataScannerViewController) {
            guard !didEmit else {
                return
            }
            for item in items {
                if case let .barcode(barcode) = item,
                   let value = barcode.payloadStringValue,
                   !value.isEmpty {
                    didEmit = true
                    dataScanner.stopScanning()
                    onBarcode(value)
                    return
                }
            }
        }
    }
}
#endif
