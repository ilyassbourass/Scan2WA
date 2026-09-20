import SwiftUI
import AVFoundation
import PhotosUI

public struct PackagePhotoCaptureView: View {
    public let initialPhoneNumber: String
    public let initialCleanNumber: String
    public let onDismiss: () -> Void
    public let onSaved: ((PackageModel) -> Void)?

    @StateObject private var camera = PackageCameraManager()
    @State private var capturedImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var detectedNumbers: [RecognizedNumber] = []
    @State private var isAnalyzingPhoto: Bool = false
    @State private var selectedNumberString: String = ""
    @State private var notesText: String = ""
    @State private var locationLinkText: String = ""
    @State private var selectedStatus: DeliveryStatus = .confirme
    @State private var isSaving: Bool = false

    @FocusState private var isInputFocused: Bool

    public init(
        phoneNumber: String = "",
        cleanNumber: String = "",
        onDismiss: @escaping () -> Void,
        onSaved: ((PackageModel) -> Void)? = nil
    ) {
        self.initialPhoneNumber = phoneNumber
        self.initialCleanNumber = cleanNumber
        self.onDismiss = onDismiss
        self.onSaved = onSaved
    }

    private var effectiveLastTwoDigits: String {
        let digits = selectedNumberString.filter { $0.isNumber }
        if digits.count >= 2 {
            return String(digits.suffix(2))
        }
        return digits.isEmpty ? "--" : digits
    }

    private var isSaveDisabled: Bool {
        isSaving || selectedNumberString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if !initialCleanNumber.isEmpty && selectedNumberString.isEmpty {
                selectedNumberString = initialCleanNumber
            }
            camera.setup()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let rawImage = UIImage(data: data) {
                    let normalized = rawImage.fixOrientation()
                    await MainActor.run {
                        withAnimation(.easeInOut) {
                            self.capturedImage = normalized
                        }
                        self.analyzeImage(normalized)
                    }
                }
            }
        }
    }

    private func analyzeImage(_ image: UIImage) {
        isAnalyzingPhoto = true
        VisionTextRecognizer.shared.processImage(image) { numbers in
            DispatchQueue.main.async {
                self.detectedNumbers = numbers
                self.isAnalyzingPhoto = false
                if self.selectedNumberString.isEmpty, let first = numbers.first {
                    self.selectedNumberString = first.cleanNumber
                    let haptic = UIImpactFeedbackGenerator(style: .medium)
                    haptic.impactOccurred()
                }
            }
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

                    // Package badge & phone number (if known) or title
                    if !selectedNumberString.isEmpty {
                        HStack(spacing: 8) {
                            Text("#\(effectiveLastTwoDigits)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                                .foregroundColor(.black)
                                .cornerRadius(6)

                            Text(selectedNumberString)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    } else {
                        Text("Photo du Colis")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(20)
                    }

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

                // Bottom instructions, shutter button & PhotosPicker button
                VStack(spacing: 16) {
                    Text("Cadrez l'étiquette du colis et prenez une photo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)

                    HStack(spacing: 0) {
                        // Left: Camera Roll PhotosPicker button
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.65))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Center: Big Shutter button
                        Button(action: {
                            camera.capturePhoto { image in
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                withAnimation(.easeInOut) {
                                    self.capturedImage = image
                                }
                                self.analyzeImage(image)
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
                        .frame(maxWidth: .infinity)

                        // Right: Spacer to balance layout
                        Color.clear
                            .frame(width: 52, height: 52)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
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
                            self.selectedPhotoItem = nil
                            self.detectedNumbers = []
                            if initialCleanNumber.isEmpty {
                                self.selectedNumberString = ""
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reprendre")
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
                    Text("#\(effectiveLastTwoDigits)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedStatus.color)
                        .foregroundColor(selectedStatus.textColorOnStatus)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                // Photo preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)

                // Package Details Card
                VStack(spacing: 16) {
                    // OCR Scanning state
                    if isAnalyzingPhoto {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            Text("Recherche automatique des numéros...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.vertical, 6)
                    }

                    // Section: Detected Numbers (if any)
                    if !detectedNumbers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NUMÉROS DÉTECTÉS (\(detectedNumbers.count)) — APPUYEZ POUR CHOISIR")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(detectedNumbers) { num in
                                        Button(action: {
                                            selectedNumberString = num.cleanNumber
                                            let haptic = UIImpactFeedbackGenerator(style: .light)
                                            haptic.impactOccurred()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "phone.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                                Text(num.cleanNumber)
                                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                if selectedNumberString == num.cleanNumber {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selectedNumberString == num.cleanNumber ? Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.22) : Color.white.opacity(0.08))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedNumberString == num.cleanNumber ? Color(red: 0.15, green: 0.78, blue: 0.35) : Color.clear, lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Divider().background(Color.white.opacity(0.2))
                    }

                    // Section: Editable Phone Number / 2 Digits
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("NUMÉRO OU 2 DERNIERS CHIFFRES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if !effectiveLastTwoDigits.isEmpty && effectiveLastTwoDigits != "--" {
                                Text("Index: #\(effectiveLastTwoDigits)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(selectedStatus.color)
                            }
                        }

                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            TextField("Ex: 0612345678 ou juste 73", text: $selectedNumberString)
                                .focused($isInputFocused)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .keyboardType(.numbersAndPunctuation)

                            if !selectedNumberString.isEmpty {
                                Button(action: { selectedNumberString = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)

                        if detectedNumbers.isEmpty && !isAnalyzingPhoto {
                            Text("💡 Aucun numéro détecté. Vous pouvez saisir le numéro complet ou simplement les 2 derniers chiffres (ex: 73) pour l'enregistrer.")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }

                    Divider().background(Color.white.opacity(0.2))

                    // Status Selector (Confirmé, Livré, Reporté, Annulé)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHOISIR STATUT DU COLIS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(DeliveryStatus.allCases) { status in
                                Button(action: {
                                    selectedStatus = status
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: status.iconName)
                                            .font(.system(size: 11, weight: .bold))
                                        Text(status.rawValue)
                                            .font(.system(size: 12, weight: .bold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedStatus == status ? status.color : Color.white.opacity(0.08))
                                    .foregroundColor(selectedStatus == status ? status.textColorOnStatus : .white)
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
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: selectedStatus.textColorOnStatus == .white ? .white : .black))
                            } else {
                                Image(systemName: selectedStatus.iconName)
                                    .font(.system(size: 18, weight: .bold))
                                Text("Save as \(selectedStatus.rawValue)")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedStatus.color.opacity(isSaveDisabled ? 0.35 : 1.0))
                        .foregroundColor(selectedStatus.textColorOnStatus.opacity(isSaveDisabled ? 0.5 : 1.0))
                        .cornerRadius(14)
                    }
                    .disabled(isSaveDisabled)

                    // Try Again / Retake Button
                    Button(action: {
                        withAnimation {
                            self.capturedImage = nil
                            self.selectedPhotoItem = nil
                            self.detectedNumbers = []
                            if initialCleanNumber.isEmpty {
                                self.selectedNumberString = ""
                            }
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
        let clean = selectedNumberString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let image = capturedImage, !clean.isEmpty else { return }
        isSaving = true

        let saved = PackageManager.shared.savePackage(
            phoneNumber: clean,
            cleanNumber: clean,
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
