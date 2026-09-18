import SwiftUI
import AVFoundation

public struct PackagePhotoCaptureView: View {
    public let phoneNumber: String
    public let cleanNumber: String
    public let onDismiss: () -> Void
    public let onSaved: ((PackageModel) -> Void)?

    @StateObject private var camera = PackageCameraManager()
    @State private var capturedImage: UIImage? = nil
    @State private var notesText: String = ""
    @State private var locationLinkText: String = ""
    @State private var isSaving: Bool = false

    public init(
        phoneNumber: String,
        cleanNumber: String,
        onDismiss: @escaping () -> Void,
        onSaved: ((PackageModel) -> Void)? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.cleanNumber = cleanNumber
        self.onDismiss = onDismiss
        self.onSaved = onSaved
    }

    private var lastTwoDigits: String {
        let digits = cleanNumber.filter { $0.isNumber }
        return digits.count >= 2 ? String(digits.suffix(2)) : digits
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = capturedImage {
                // MARK: - Review & Save View
                reviewView(image: image)
            } else {
                // MARK: - Live Camera View
                cameraView
            }
        }
        .onAppear {
            camera.setup()
        }
        .onDisappear {
            camera.stop()
        }
    }

    // MARK: - Live Camera View
    private var cameraView: some View {
        ZStack {
            PackageCameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Top Navigation Bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Package badge & phone number
                    HStack(spacing: 8) {
                        Text("#\(lastTwoDigits)")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                            .foregroundColor(.black)
                            .cornerRadius(6)

                        Text(cleanNumber)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)

                    Spacer()

                    // Torch toggle
                    Button(action: camera.toggleTorch) {
                        Image(systemName: camera.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(camera.isTorchOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                Spacer()

                // Bottom instructions and shutter button
                VStack(spacing: 16) {
                    Text("Align the package in frame and tap shutter")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)

                    Button(action: {
                        camera.capturePhoto { image in
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation(.easeInOut) {
                                self.capturedImage = image
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 62, height: 62)
                        }
                    }
                    .padding(.bottom, 36)
                }
            }
        }
    }

    // MARK: - Review and Save View
    private func reviewView(image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top bar in review mode
                HStack {
                    Button(action: {
                        withAnimation {
                            self.capturedImage = nil
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(20)
                    }

                    Spacer()

                    // Badge
                    Text("#\(lastTwoDigits)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                // Photo preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                // Package Details Card
                VStack(spacing: 14) {
                    // Phone Number Header
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                        Text(cleanNumber)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    Divider().background(Color.white.opacity(0.2))

                    // Notes input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES (OPTIONAL)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField("e.g., Apt 4, 250 DH COD, leave with concierge", text: $notesText)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                    }

                    // Location Link input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("LOCATION LINK (OPTIONAL)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: pasteLocationFromClipboard) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            }
                        }

                        TextField("e.g. Google Maps or WhatsApp location link", text: $locationLinkText)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                // Action Buttons: Save or Try Again
                VStack(spacing: 12) {
                    // Save Button
                    Button(action: savePackageAction) {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Save Package")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                        .foregroundColor(.black)
                        .cornerRadius(14)
                    }
                    .disabled(isSaving)

                    // Try Again / Retake Button
                    Button(action: {
                        withAnimation {
                            self.capturedImage = nil
                        }
                    }) {
                        Text("Try Again (Retake Photo)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 36)
            }
        }
    }

    private func pasteLocationFromClipboard() {
        if let paste = UIPasteboard.general.string, !paste.isEmpty {
            self.locationLinkText = paste
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func savePackageAction() {
        guard let image = capturedImage else { return }
        isSaving = true

        let saved = PackageManager.shared.savePackage(
            phoneNumber: phoneNumber,
            cleanNumber: cleanNumber,
            image: image,
            locationLink: locationLinkText,
            notes: notesText
        )

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if let saved = saved {
            onSaved?(saved)
        }

        onDismiss()
    }
}

// MARK: - Package Camera Manager
fileprivate final class PackageCameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?
    private var photoCompletion: ((UIImage) -> Void)?
    @Published var isTorchOn: Bool = false

    func setup() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTripleCamera],
                mediaType: .video,
                position: .back
            )

            guard let device = discovery.devices.first,
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                return
            }

            self.videoDevice = device

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func toggleTorch() {
        guard let device = videoDevice, device.hasTorch else { return }
        try? device.lockForConfiguration()
        if device.torchMode == .on {
            device.torchMode = .off
            DispatchQueue.main.async { self.isTorchOn = false }
        } else {
            try? device.setTorchModeOn(level: 1.0)
            DispatchQueue.main.async { self.isTorchOn = true }
        }
        device.unlockForConfiguration()
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        self.photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }

        DispatchQueue.main.async {
            self.photoCompletion?(image)
        }
    }
}

// MARK: - Package Camera Preview
fileprivate struct PackageCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        if #available(iOS 17.0, *) {
            preview.connection?.videoRotationAngle = 90
        } else {
            preview.connection?.videoOrientation = .portrait
        }
        view.layer.addSublayer(preview)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            preview.frame = uiView.bounds
        }
    }
}
