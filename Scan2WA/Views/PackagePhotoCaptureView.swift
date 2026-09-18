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
    @State private var selectedStatus: DeliveryStatus = .livre
    @State private var isSaving: Bool = false

    @FocusState private var isInputFocused: Bool

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
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
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
                        .background(selectedStatus.color)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                // Photo preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                // Package Details Card
                VStack(spacing: 16) {
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

                    // Status Selector (Livré, Reporté, Annulé)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHOISIR STATUT DU COLIS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(DeliveryStatus.allCases) { status in
                                Button(action: {
                                    selectedStatus = status
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: status.iconName)
                                            .font(.system(size: 12, weight: .bold))
                                        Text(status.rawValue)
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedStatus == status ? status.color : Color.white.opacity(0.08))
                                    .foregroundColor(selectedStatus == status ? .black : .white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedStatus == status ? status.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }
                        }
                    }

                    // Notes input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES (OPTIONAL)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField("e.g., Apt 4, 250 DH COD, leave with concierge", text: $notesText)
                            .focused($isInputFocused)
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
                            .focused($isInputFocused)
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
                    // Save Button with Selected Status Color
                    Button(action: savePackageAction) {
                        HStack(spacing: 10) {
                            if isSaving {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                            } else {
                                Image(systemName: selectedStatus.iconName)
                                    .font(.system(size: 18, weight: .bold))
                                Text("Save as \(selectedStatus.rawValue)")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedStatus.color)
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputFocused = false
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
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
            notes: notesText,
            status: selectedStatus
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
    private let cameraQueue = DispatchQueue(label: "com.scan2wa.packageCameraQueue")
    @Published var isTorchOn: Bool = false

    func setup() {
        cameraQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
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
                if let connection = self.photoOutput.connection(with: .video) {
                    if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(90) {
                        connection.videoRotationAngle = 90
                    } else if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }

            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    func stop() {
        cameraQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func toggleTorch() {
        guard let device = videoDevice, device.hasTorch else { return }
        cameraQueue.async {
            do {
                try device.lockForConfiguration()
                if device.torchMode == .on {
                    device.torchMode = .off
                    DispatchQueue.main.async { self.isTorchOn = false }
                } else {
                    try device.setTorchModeOn(level: 1.0)
                    DispatchQueue.main.async { self.isTorchOn = true }
                }
                device.unlockForConfiguration()
            } catch {
                print("Torch error: \(error)")
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage) -> Void) {
        self.photoCompletion = completion
        cameraQueue.async { [weak self] in
            guard let self = self else { return }
            if let connection = self.photoOutput.connection(with: .video) {
                if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                } else if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let callback = self.photoCompletion
        self.photoCompletion = nil

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let rawImage = UIImage(data: data) else {
            return
        }

        let normalized = rawImage.fixOrientation()

        DispatchQueue.main.async {
            callback?(normalized)
        }
    }
}

// MARK: - Package Camera Preview (Backing Layer UIView Pattern)
fileprivate class PackageVideoPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        if let conn = previewLayer.connection {
            if #available(iOS 17.0, *), conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
            } else if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }
    }
}

fileprivate struct PackageCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PackageVideoPreviewUIView {
        let view = PackageVideoPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let conn = view.previewLayer.connection {
            if #available(iOS 17.0, *), conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
            } else if conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
        }
        return view
    }

    func updateUIView(_ uiView: PackageVideoPreviewUIView, context: Context) {
        uiView.previewLayer.frame = uiView.bounds
    }
}

// MARK: - UIImage Orientation Normalizer
fileprivate extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}
