import FoodWalletCore
import SwiftUI

#if os(iOS)
import VisionKit
import Vision
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
    var onQRCode: (String) -> Void = { _ in }
    var onScannerError: (String) -> Void = { _ in }

    var body: some View {
        #if os(iOS)
        if #available(iOS 16.0, *), BarcodeScannerAvailability.canUseCameraScanner {
            VisionKitBarcodeScannerView(
                onBarcode: onBarcode,
                onQRCode: onQRCode,
                onScannerError: onScannerError
            )
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
    var onQRCode: (String) -> Void
    var onScannerError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode, onQRCode: onQRCode, onScannerError: onScannerError)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce, .qr]),
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
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
        do {
            try uiViewController.startScanning()
        } catch {
            context.coordinator.emitScannerError("Camera scanner could not start. Enter the barcode digits below.")
        }
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private var didEmit = false
        private var didReportScannerError = false
        private var barcodeStabilityTracker = CameraBarcodeStabilityTracker()
        private let onBarcode: (String) -> Void
        private let onQRCode: (String) -> Void
        private let onScannerError: (String) -> Void

        init(
            onBarcode: @escaping (String) -> Void,
            onQRCode: @escaping (String) -> Void,
            onScannerError: @escaping (String) -> Void
        ) {
            self.onBarcode = onBarcode
            self.onQRCode = onQRCode
            self.onScannerError = onScannerError
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emitPreferredBarcode(from: allItems, allowsShortBarcode: false, dataScanner: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emitPreferredBarcode(from: allItems, allowsShortBarcode: false, dataScanner: dataScanner)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            emitPreferredBarcode(from: [item], allowsShortBarcode: true, dataScanner: dataScanner)
        }

        private func emitPreferredBarcode(
            from items: [RecognizedItem],
            allowsShortBarcode: Bool,
            dataScanner: DataScannerViewController
        ) {
            guard !didEmit else {
                return
            }
            let values = items.compactMap { item -> String? in
                guard case let .barcode(barcode) = item else {
                    return nil
                }
                return barcode.payloadStringValue
            }
            if let qrValue = values.first(where: Self.isMealMarkQRCode) {
                didEmit = true
                dataScanner.stopScanning()
                onQRCode(qrValue)
                return
            }
            if let normalizedValue = barcodeStabilityTracker.observe(
                values,
                allowsShortBarcode: allowsShortBarcode,
                requiredObservations: allowsShortBarcode ? 1 : 2
            ) {
                didEmit = true
                dataScanner.stopScanning()
                onBarcode(normalizedValue)
            }
        }

        private static func isMealMarkQRCode(_ value: String?) -> Bool {
            guard let value else {
                return false
            }
            return value.hasPrefix("GR1:") ||
                value.contains("\"grain.food-wallet.qr.v1\"") ||
                value.contains("grain.food-wallet.qr.v1")
        }

        func emitScannerError(_ message: String) {
            guard !didReportScannerError else {
                return
            }
            didReportScannerError = true
            onScannerError(message)
        }
    }
}
#endif
