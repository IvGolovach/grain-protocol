import FoodWalletCore
import SwiftUI

#if os(iOS)
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    var onPhotoCaptured: (TransientMealPhotoPayload) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPhotoCaptured: onPhotoCaptured, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onPhotoCaptured: (TransientMealPhotoPayload) -> Void
        private let onCancel: () -> Void

        init(onPhotoCaptured: @escaping (TransientMealPhotoPayload) -> Void, onCancel: @escaping () -> Void) {
            self.onPhotoCaptured = onPhotoCaptured
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer {
                picker.dismiss(animated: true)
            }

            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }

            guard let photoPayload = TransientMealPhotoPayload.transientCapture(from: image) else {
                onCancel()
                return
            }

            onPhotoCaptured(photoPayload)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}

private extension TransientMealPhotoPayload {
    static func transientCapture(from image: UIImage) -> TransientMealPhotoPayload? {
        let normalizedImage = image.foodWalletScaledForAnalysis()
        guard let jpegData = normalizedImage.foodWalletJPEGDataForAnalysis() else {
            return nil
        }

        let pixelsWide = Int(normalizedImage.size.width * normalizedImage.scale)
        let pixelsHigh = Int(normalizedImage.size.height * normalizedImage.scale)
        let photo = CapturedMealPhoto(
            id: "camera-\(UUID().uuidString)",
            widthPixels: pixelsWide,
            heightPixels: pixelsHigh,
            compressedByteCount: jpegData.count,
            features: normalizedImage.foodWalletFeatures()
        )

        return TransientMealPhotoPayload(photo: photo, jpegData: jpegData)
    }
}

private extension UIImage {
    func foodWalletScaledForAnalysis() -> UIImage {
        let maxPixelDimension = CGFloat(1_600)
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let largestDimension = max(pixelWidth, pixelHeight)
        guard largestDimension > maxPixelDimension, largestDimension > 0 else {
            return self
        }

        let ratio = maxPixelDimension / largestDimension
        let targetSize = CGSize(
            width: max(1, round(pixelWidth * ratio)),
            height: max(1, round(pixelHeight * ratio))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func foodWalletJPEGDataForAnalysis() -> Data? {
        let maxBytes = 2_500_000
        for quality in stride(from: 0.72, through: 0.42, by: -0.10) {
            guard let data = jpegData(compressionQuality: quality) else {
                continue
            }
            if data.count <= maxBytes {
                return data
            }
        }
        return jpegData(compressionQuality: 0.32)
    }

    func foodWalletFeatures() -> FoodPhotoFeatures {
        guard let cgImage else {
            return .unknown
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let rendered = pixel.withUnsafeMutableBytes { bytes in
            CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }

        guard let context = rendered else {
            return .unknown
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let red = Double(pixel[0]) / 255
        let green = Double(pixel[1]) / 255
        let blue = Double(pixel[2]) / 255
        let brightness = (red + green + blue) / 3

        return FoodPhotoFeatures(
            redBalance: red,
            greenBalance: green,
            blueBalance: blue,
            brightness: brightness
        )
    }
}
#endif
