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
        guard let jpegData = image.jpegData(compressionQuality: 0.65) else {
            return nil
        }

        let pixelsWide = Int(image.size.width * image.scale)
        let pixelsHigh = Int(image.size.height * image.scale)
        let photo = CapturedMealPhoto(
            id: "camera-\(UUID().uuidString)",
            widthPixels: pixelsWide,
            heightPixels: pixelsHigh,
            compressedByteCount: jpegData.count,
            features: image.foodWalletFeatures()
        )

        return TransientMealPhotoPayload(photo: photo, jpegData: jpegData)
    }
}

private extension UIImage {
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
