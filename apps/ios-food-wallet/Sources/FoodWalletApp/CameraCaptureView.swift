import FoodWalletCore
import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    var onPhotoCaptured: (TransientMealPhotoPayload) -> Void
    var onCancel: () -> Void
    var onUnavailable: (String) -> Void = { _ in }

    func makeUIViewController(context: Context) -> MealMarkCameraViewController {
        MealMarkCameraViewController(
            onPhotoCaptured: onPhotoCaptured,
            onCancel: onCancel,
            onUnavailable: onUnavailable
        )
    }

    func updateUIViewController(_ uiViewController: MealMarkCameraViewController, context: Context) {}
}

final class MealMarkCameraViewController: UIViewController {
    private let onPhotoCaptured: (TransientMealPhotoPayload) -> Void
    private let onCancel: () -> Void
    private let onUnavailable: (String) -> Void
    private nonisolated(unsafe) let session = AVCaptureSession()
    private nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "dev.grain.mealmark.camera-session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoDelegate: PhotoCaptureDelegate?
    private nonisolated(unsafe) var isConfigured = false

    private let closeButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let helperLabel = UILabel()

    init(
        onPhotoCaptured: @escaping (TransientMealPhotoPayload) -> Void,
        onCancel: @escaping () -> Void,
        onUnavailable: @escaping (String) -> Void
    ) {
        self.onPhotoCaptured = onPhotoCaptured
        self.onCancel = onCancel
        self.onUnavailable = onUnavailable
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configurePreview()
        configureOverlay()
        requestAccessAndConfigure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else {
                return
            }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else {
                return
            }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configurePreview() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func configureOverlay() {
        let topGradient = GradientView(topColor: UIColor.black.withAlphaComponent(0.78), bottomColor: .clear)
        topGradient.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topGradient)

        let bottomGradient = GradientView(topColor: .clear, bottomColor: UIColor.black.withAlphaComponent(0.86))
        bottomGradient.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomGradient)

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        closeButton.layer.cornerRadius = 28
        closeButton.accessibilityLabel = "Close camera"
        closeButton.accessibilityIdentifier = "MealMarkCameraCloseButton"
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        titleLabel.text = "Meal photo"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        helperLabel.text = "Capture food or a readable nutrition label"
        helperLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        helperLabel.font = .systemFont(ofSize: 14, weight: .medium)
        helperLabel.textAlignment = .center
        helperLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helperLabel)

        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 37
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        shutterButton.layer.borderWidth = 7
        shutterButton.accessibilityLabel = "Take meal photo"
        shutterButton.accessibilityIdentifier = "MealMarkCameraShutterButton"
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            topGradient.topAnchor.constraint(equalTo: view.topAnchor),
            topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topGradient.heightAnchor.constraint(equalToConstant: 160),

            bottomGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomGradient.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomGradient.heightAnchor.constraint(equalToConstant: 220),

            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 56),
            closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 16),

            helperLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            helperLabel.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -28),
            helperLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            helperLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34),
            shutterButton.widthAnchor.constraint(equalToConstant: 74),
            shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor),
        ])
    }

    private func requestAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.configureSession()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.onUnavailable("Camera access is off for MealMark. Enable camera access in Settings, or add the ingredient from a typed entry or barcode.")
                    }
                }
            }
        case .denied:
            onUnavailable("Camera access is off for MealMark. Enable camera access in Settings, or add the ingredient from a typed entry or barcode.")
        case .restricted:
            onUnavailable("Camera capture is restricted on this device. You can still add food by typing, barcode, or photo library.")
        @unknown default:
            onUnavailable("MealMark could not start the camera on this device. Try again or use another add-food method.")
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else {
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: camera),
                self.session.canAddInput(input),
                self.session.canAddOutput(self.photoOutput)
            else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.onUnavailable("MealMark could not find a usable rear camera. Try barcode entry, photo library, or manual ingredients.")
                }
                return
            }

            self.session.addInput(input)
            self.session.addOutput(self.photoOutput)
            self.isConfigured = true
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    @objc private func cancel() {
        onCancel()
    }

    @objc private func capturePhoto() {
        shutterButton.isEnabled = false
        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate { [weak self] image in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.shutterButton.isEnabled = true
                self.photoDelegate = nil
                guard
                    let image,
                    let payload = TransientMealPhotoPayload.transientCapture(from: image)
                else {
                    self.onUnavailable("MealMark could not read this camera photo. Try taking the photo again.")
                    return
                }
                self.onPhotoCaptured(payload)
            }
        }
        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            guard error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }
    }
}

private final class GradientView: UIView {
    private let topColor: UIColor
    private let bottomColor: UIColor

    init(topColor: UIColor, bottomColor: UIColor) {
        self.topColor = topColor
        self.bottomColor = bottomColor
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layer = layer as? CAGradientLayer else {
            return
        }
        layer.colors = [topColor.cgColor, bottomColor.cgColor]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
    }
}

extension TransientMealPhotoPayload {
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
