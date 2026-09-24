import SwiftUI
import AVFoundation
import PhotosUI

// MARK: - Capture Mode Enum
public enum CaptureMode: String, CaseIterable, Identifiable {
    case single = "Single"
    case batch = "Multi-Batch"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .single: return "shippingbox.fill"
        case .batch: return "square.stack.3d.up.fill"
        }
    }
}

// MARK: - Batch Package Item Model
public struct BatchPackageItem: Identifiable {
    public let id: UUID = UUID()
    public let image: UIImage
    public var detectedNumbers: [RecognizedNumber] = []
    public var isAnalyzing: Bool = true
    public var selectedNumberString: String = ""
    public var notesText: String = ""
    public var locationLinkText: String = ""
    public var selectedStatus: DeliveryStatus = .confirme
    public var isSaved: Bool = false
    public var savedPackageId: UUID? = nil

    public var effectiveLastTwoDigits: String {
        let digits = selectedNumberString.filter { $0.isNumber }
        if digits.count >= 2 {
            return String(digits.suffix(2))
        }
        return digits.isEmpty ? "--" : digits
    }

    public var isSaveDisabled: Bool {
        selectedNumberString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Package Photo Capture View
public struct PackagePhotoCaptureView: View {
    public let initialPhoneNumber: String
    public let initialCleanNumber: String
    public let onDismiss: () -> Void
    public let onSaved: ((PackageModel) -> Void)?

    @StateObject private var camera = PackageCameraManager()

    // Mode: Single vs Multi-Batch
    @State private var captureMode: CaptureMode = .single

    // Single & Multi Photo Selection States
    @State private var capturedImage: UIImage? = nil
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos: Bool = false
    @State private var loadingPhotosCount: Int = 0
    @State private var detectedNumbers: [RecognizedNumber] = []
    @State private var isAnalyzingPhoto: Bool = false
    @State private var selectedNumberString: String = ""
    @State private var notesText: String = ""
    @State private var locationLinkText: String = ""
    @State private var selectedStatus: DeliveryStatus = .confirme
    @State private var isSaving: Bool = false

    // Multi-Batch Capture States
    @State private var batchItems: [BatchPackageItem] = []
    @State private var isReviewingBatch: Bool = false
    @State private var currentBatchIndex: Int = 0
    @State private var showShutterFlash: Bool = false

    // Duplicate Warning States
    @State private var duplicateExistingPackage: PackageModel? = nil
    @State private var isDuplicateBatchItem: Bool = false

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

            if isReviewingBatch && !batchItems.isEmpty {
                // MARK: - Multi-Batch Review View
                batchReviewView
            } else if let image = capturedImage {
                // MARK: - Single Review & Save View
                singleReviewView(image: image)
            } else {
                // MARK: - Live Camera View (Single or Batch)
                cameraView
            }

            // Shutter Flash Animation (for Batch Mode)
            if showShutterFlash {
                Color.white.opacity(0.65)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Loading Photos Overlay
            if isLoadingPhotos {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.15, green: 0.78, blue: 0.35)))
                            .scaleEffect(1.3)
                        Text("Importing \(loadingPhotosCount) photos...")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
                .transition(.opacity)
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
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            isLoadingPhotos = true
            loadingPhotosCount = newItems.count
            Task {
                var loadedImages: [UIImage] = []
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let rawImage = UIImage(data: data) {
                        loadedImages.append(rawImage.fixOrientation())
                    }
                }
                await MainActor.run {
                    self.isLoadingPhotos = false
                    guard !loadedImages.isEmpty else { return }

                    if loadedImages.count == 1 && self.captureMode == .single && self.batchItems.isEmpty {
                        withAnimation(.easeInOut) {
                            self.capturedImage = loadedImages[0]
                        }
                        self.analyzeSingleImage(loadedImages[0])
                    } else {
                        // Multi-photo selection or batch mode
                        for img in loadedImages {
                            self.addBatchItem(image: img)
                        }
                        withAnimation(.easeInOut) {
                            self.captureMode = .batch
                            self.currentBatchIndex = 0
                            self.isReviewingBatch = true
                        }
                    }
                    self.selectedPhotoItems = []
                }
            }
        }
        .sheet(item: $duplicateExistingPackage) { duplicate in
            DuplicateWarningSheet(
                existingPackage: duplicate,
                newNumber: isDuplicateBatchItem ? (currentBatchIndex < batchItems.count ? batchItems[currentBatchIndex].selectedNumberString : "") : selectedNumberString,
                newImage: isDuplicateBatchItem ? (currentBatchIndex < batchItems.count ? batchItems[currentBatchIndex].image : nil) : capturedImage,
                onSaveAnyway: {
                    duplicateExistingPackage = nil
                    if isDuplicateBatchItem {
                        executeSaveCurrentBatchPackageAction()
                    } else {
                        executeSaveSinglePackageAction()
                    }
                },
                onDelete: {
                    duplicateExistingPackage = nil
                    if isDuplicateBatchItem {
                        deleteCurrentBatchItem()
                    } else {
                        capturedImage = nil
                        selectedNumberString = ""
                        onDismiss()
                    }
                },
                onCancel: {
                    duplicateExistingPackage = nil
                }
            )
        }
    }

    // MARK: - Single Image Analysis
    private func analyzeSingleImage(_ image: UIImage) {
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

    // MARK: - Batch Item Helper
    private func addBatchItem(image: UIImage) {
        var newItem = BatchPackageItem(image: image)
        newItem.notesText = "\(batchItems.count + 1)"
        batchItems.append(newItem)
        let itemIndex = batchItems.count - 1

        // Background OCR Analysis concurrently
        VisionTextRecognizer.shared.processImage(image) { numbers in
            DispatchQueue.main.async {
                if itemIndex < self.batchItems.count {
                    self.batchItems[itemIndex].detectedNumbers = numbers
                    self.batchItems[itemIndex].isAnalyzing = false
                    if self.batchItems[itemIndex].selectedNumberString.isEmpty, let first = numbers.first {
                        self.batchItems[itemIndex].selectedNumberString = first.cleanNumber
                    }
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

                    // Mode Switcher Pill: [ Single | Multi-Batch ]
                    HStack(spacing: 4) {
                        ForEach(CaptureMode.allCases) { mode in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    captureMode = mode
                                }
                                let haptic = UIImpactFeedbackGenerator(style: .light)
                                haptic.impactOccurred()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(mode.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(captureMode == mode ? Color(red: 0.15, green: 0.78, blue: 0.35) : Color.clear)
                                .foregroundColor(captureMode == mode ? .black : .white)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))

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

                // Bottom Controls & Shutter
                VStack(spacing: 16) {
                    // Hint text
                    if captureMode == .batch {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.yellow)
                            Text(batchItems.isEmpty ? "Snap all packages one by one, then tap 'Review'" : "\(batchItems.count) package\(batchItems.count == 1 ? "" : "s") captured — tap shutter for more")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                    } else {
                        Text("Align the package label and snap photo")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                    }

                    // Shutter Row
                    HStack(spacing: 0) {
                        // Left: Camera Roll PhotosPicker button
                        PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
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

                                if captureMode == .batch {
                                    // Flash effect
                                    withAnimation(.easeIn(duration: 0.08)) {
                                        showShutterFlash = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            showShutterFlash = false
                                        }
                                    }
                                    addBatchItem(image: image)
                                } else {
                                    withAnimation(.easeInOut) {
                                        self.capturedImage = image
                                    }
                                    self.analyzeSingleImage(image)
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(captureMode == .batch ? Color.yellow : Color.white, lineWidth: 4)
                                    .frame(width: 76, height: 76)
                                Circle()
                                    .fill(captureMode == .batch ? Color.yellow : Color.white)
                                    .frame(width: 62, height: 62)

                                if captureMode == .batch && !batchItems.isEmpty {
                                    Text("\(batchItems.count)")
                                        .font(.system(size: 20, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Right: "Review (N) ➔" button for Batch Mode
                        if captureMode == .batch && !batchItems.isEmpty {
                            Button(action: {
                                currentBatchIndex = 0
                                withAnimation(.easeInOut) {
                                    isReviewingBatch = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text("Review (\(batchItems.count))")
                                        .font(.system(size: 13, weight: .bold))
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(red: 0.15, green: 0.78, blue: 0.35))
                                .foregroundColor(.black)
                                .cornerRadius(20)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(width: 52, height: 52)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    // MARK: - Single Review and Save View
    private func singleReviewView(image: UIImage) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top bar in review mode
                HStack {
                    Button(action: {
                        withAnimation {
                            self.capturedImage = nil
                            self.selectedPhotoItems = []
                            self.detectedNumbers = []
                            if initialCleanNumber.isEmpty {
                                self.selectedNumberString = ""
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retake")
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

                // In-Place Zoomable Photo Preview
                InPlaceZoomableImageView(image: image)
                    .padding(.horizontal, 20)

                // Package Details Card
                VStack(spacing: 16) {
                    // OCR Scanning state
                    if isAnalyzingPhoto {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            Text("Automatically detecting phone numbers...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.vertical, 6)
                    }

                    // Section: Detected Numbers (if any)
                    if !detectedNumbers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DETECTED NUMBERS (\(detectedNumbers.count)) — TAP TO SELECT")
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
                            Text("PHONE NUMBER OR LAST 2 DIGITS")
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
                            TextField("e.g. 0612345678 or just 73", text: $selectedNumberString)
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
                            Text("💡 No phone number detected. Enter the full number or just the last 2 digits (e.g. 73) to save.")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }

                    Divider().background(Color.white.opacity(0.2))

                    // Status Selector (Confirmé, Livré, Reporté, Annulé)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SELECT PACKAGE STATUS")
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

                    // Notes input with 1-tap quick number chips
                    QuickNumberNotesPicker(
                        notesText: $notesText,
                        placeholder: "e.g., Apt 4, 250 DH COD, leave with concierge"
                    )

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

                // Action Buttons: Save or Retake
                VStack(spacing: 12) {
                    // Save Button with Selected Status Color
                    Button(action: saveSinglePackageAction) {
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

                    // Retake Button
                    Button(action: {
                        withAnimation {
                            self.capturedImage = nil
                            self.selectedPhotoItems = []
                            self.detectedNumbers = []
                            if initialCleanNumber.isEmpty {
                                self.selectedNumberString = ""
                            }
                        }
                    }) {
                        Text("Retake Photo")
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

    // MARK: - Multi-Batch Review View
    @ViewBuilder
    private var batchReviewView: some View {
        if currentBatchIndex < batchItems.count && !batchItems.isEmpty {
            let currentItem = batchItems[currentBatchIndex]

            ScrollView {
            VStack(spacing: 16) {
                // Top Batch Bar
                HStack {
                    // Back to Camera button
                    Button(action: {
                        withAnimation {
                            isReviewingBatch = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                            Text("+ Add More")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(16)
                    }

                    Spacer()

                    // Step indicator: Package 1 of 4
                    VStack(spacing: 2) {
                        Text("Package \(currentBatchIndex + 1) of \(batchItems.count)")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.white)

                        // Mini progress dots
                        HStack(spacing: 4) {
                            ForEach(0..<batchItems.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == currentBatchIndex ? Color(red: 0.15, green: 0.78, blue: 0.35) : (batchItems[idx].isSaved ? Color.blue : Color.white.opacity(0.25)))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }

                    Spacer()

                    // Trash button to discard this specific package
                    Button(action: deleteCurrentBatchItem) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)

                // In-Place Zoomable Image for Current Batch Item
                InPlaceZoomableImageView(image: currentItem.image)
                    .padding(.horizontal, 20)

                // Package Details Card
                VStack(spacing: 16) {
                    // Analyzing indicator
                    if currentItem.isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            Text("Automatically detecting phone numbers...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.vertical, 6)
                    }

                    // Section: Detected Numbers chips
                    if !currentItem.detectedNumbers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DETECTED NUMBERS (\(currentItem.detectedNumbers.count)) — TAP TO SELECT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(currentItem.detectedNumbers) { num in
                                        Button(action: {
                                            batchItems[currentBatchIndex].selectedNumberString = num.cleanNumber
                                            let haptic = UIImpactFeedbackGenerator(style: .light)
                                            haptic.impactOccurred()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "phone.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                                Text(num.cleanNumber)
                                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                if currentItem.selectedNumberString == num.cleanNumber {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(currentItem.selectedNumberString == num.cleanNumber ? Color(red: 0.15, green: 0.78, blue: 0.35).opacity(0.22) : Color.white.opacity(0.08))
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(currentItem.selectedNumberString == num.cleanNumber ? Color(red: 0.15, green: 0.78, blue: 0.35) : Color.clear, lineWidth: 1.5)
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
                            Text("PHONE NUMBER OR LAST 2 DIGITS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if !currentItem.effectiveLastTwoDigits.isEmpty && currentItem.effectiveLastTwoDigits != "--" {
                                Text("Index: #\(currentItem.effectiveLastTwoDigits)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(currentItem.selectedStatus.color)
                            }
                        }

                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            TextField("e.g. 0612345678 or just 73", text: Binding(
                                get: { batchItems[currentBatchIndex].selectedNumberString },
                                set: { batchItems[currentBatchIndex].selectedNumberString = $0 }
                            ))
                            .focused($isInputFocused)
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .keyboardType(.numbersAndPunctuation)

                            if !currentItem.selectedNumberString.isEmpty {
                                Button(action: { batchItems[currentBatchIndex].selectedNumberString = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)

                        if currentItem.detectedNumbers.isEmpty && !currentItem.isAnalyzing {
                            Text("💡 No phone number detected. Enter the full number or just the last 2 digits (e.g. 73) to save.")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }

                    Divider().background(Color.white.opacity(0.2))

                    // Status Selector (Confirmé, Livré, Reporté, Annulé)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SELECT PACKAGE STATUS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(DeliveryStatus.allCases) { status in
                                Button(action: {
                                    batchItems[currentBatchIndex].selectedStatus = status
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
                                    .background(currentItem.selectedStatus == status ? status.color : Color.white.opacity(0.08))
                                    .foregroundColor(currentItem.selectedStatus == status ? status.textColorOnStatus : .white)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(currentItem.selectedStatus == status ? status.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                            }
                        }
                    }

                    // Notes input with 1-tap quick number chips
                    QuickNumberNotesPicker(
                        notesText: Binding(
                            get: { batchItems[currentBatchIndex].notesText },
                            set: { batchItems[currentBatchIndex].notesText = $0 }
                        ),
                        placeholder: "e.g., Apt 4, 250 DH COD, leave with concierge"
                    )

                    // Location Link input
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("LOCATION LINK (OPTIONAL)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                if let paste = UIPasteboard.general.string, !paste.isEmpty {
                                    batchItems[currentBatchIndex].locationLinkText = paste
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                    Text("Paste")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                            }
                        }

                        TextField("e.g. Google Maps or WhatsApp location link", text: Binding(
                            get: { batchItems[currentBatchIndex].locationLinkText },
                            set: { batchItems[currentBatchIndex].locationLinkText = $0 }
                        ))
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

                // Batch Actions Bar: Prev / Next / Save
                HStack(spacing: 12) {
                    // Previous Button
                    if currentBatchIndex > 0 {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                currentBatchIndex -= 1
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Prev")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 52)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(14)
                        }
                    }

                    // Save & Next / Finish Button
                    let isLast = currentBatchIndex == batchItems.count - 1
                    Button(action: saveCurrentBatchPackageAction) {
                        HStack(spacing: 8) {
                            Image(systemName: isLast ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                            Text(isLast ? "Save & Finish (\(currentBatchIndex + 1)/\(batchItems.count))" : "Save & Next (\(currentBatchIndex + 1)/\(batchItems.count))")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(currentItem.selectedStatus.color.opacity(currentItem.isSaveDisabled ? 0.35 : 1.0))
                        .foregroundColor(currentItem.selectedStatus.textColorOnStatus.opacity(currentItem.isSaveDisabled ? 0.5 : 1.0))
                        .cornerRadius(14)
                    }
                    .disabled(currentItem.isSaveDisabled)
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
    }

    // MARK: - Actions
    private func deleteCurrentBatchItem() {
        guard currentBatchIndex < batchItems.count else { return }
        let item = batchItems[currentBatchIndex]
        if let savedId = item.savedPackageId {
            PackageManager.shared.permanentlyDelete(id: savedId)
        }
        batchItems.remove(at: currentBatchIndex)
        if batchItems.isEmpty {
            withAnimation {
                isReviewingBatch = false
            }
        } else if currentBatchIndex >= batchItems.count {
            currentBatchIndex = batchItems.count - 1
        }
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
    }

    private func saveCurrentBatchPackageAction() {
        guard currentBatchIndex < batchItems.count else { return }
        let item = batchItems[currentBatchIndex]
        let clean = item.selectedNumberString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Duplicate check in active packages (exclude itself if already saved in this session)
        if let duplicate = PackageManager.shared.findDuplicate(for: clean) {
            if duplicate.id != item.savedPackageId {
                self.duplicateExistingPackage = duplicate
                self.isDuplicateBatchItem = true
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.warning)
                return
            }
        }

        executeSaveCurrentBatchPackageAction()
    }

    private func executeSaveCurrentBatchPackageAction() {
        guard currentBatchIndex < batchItems.count else { return }
        let item = batchItems[currentBatchIndex]
        let clean = item.selectedNumberString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        if let existingId = item.savedPackageId {
            // Already saved earlier in this session -> Update it in-place!
            PackageManager.shared.updatePackageBatch(
                id: existingId,
                phoneNumber: clean,
                cleanNumber: clean,
                notes: item.notesText,
                locationLink: item.locationLinkText,
                status: item.selectedStatus
            )
        } else {
            // First time saving this batch item -> Create it!
            if let saved = PackageManager.shared.savePackage(
                phoneNumber: clean,
                cleanNumber: clean,
                image: item.image,
                locationLink: item.locationLinkText,
                notes: item.notesText,
                status: item.selectedStatus
            ) {
                batchItems[currentBatchIndex].savedPackageId = saved.id
            }
        }

        batchItems[currentBatchIndex].isSaved = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if currentBatchIndex < batchItems.count - 1 {
            withAnimation(.easeInOut) {
                currentBatchIndex += 1
            }
        } else {
            // All batch packages saved!
            onDismiss()
        }
    }

    private func pasteLocationFromClipboard() {
        if let paste = UIPasteboard.general.string, !paste.isEmpty {
            self.locationLinkText = paste
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func saveSinglePackageAction() {
        let clean = selectedNumberString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let image = capturedImage, !clean.isEmpty else { return }

        // Duplicate check in active packages
        if let duplicate = PackageManager.shared.findDuplicate(for: clean) {
            self.duplicateExistingPackage = duplicate
            self.isDuplicateBatchItem = false
            let haptic = UINotificationFeedbackGenerator()
            haptic.notificationOccurred(.warning)
            return
        }

        executeSaveSinglePackageAction()
    }

    private func executeSaveSinglePackageAction() {
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

// MARK: - In-Place Zoomable Image View
public struct InPlaceZoomableImageView: View {
    public let image: UIImage
    public var maxHeight: CGFloat = 260

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    public init(image: UIImage, maxHeight: CGFloat = 260) {
        self.image = image
        self.maxHeight = maxHeight
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { val in
                                    let newScale = lastScale * val
                                    scale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    if scale < 1.05 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            scale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                    lastScale = scale
                                },
                            DragGesture()
                                .onChanged { val in
                                    if scale > 1.05 {
                                        offset = CGSize(
                                            width: lastOffset.width + val.translation.width,
                                            height: lastOffset.height + val.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if scale > 1.05 {
                                        lastOffset = offset
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if scale > 1.2 {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.5
                                lastScale = 2.5
                            }
                        }
                    }
            }
            .frame(height: maxHeight)
            .clipped()
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            // Zoom indicator badge & reset button when zoomed in
            if scale > 1.1 {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1fx", scale))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(Color(red: 0.15, green: 0.78, blue: 0.35))
                    .cornerRadius(12)
                    .padding(8)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("Pinch to zoom")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white.opacity(0.7))
                .cornerRadius(10)
                .padding(8)
            }
        }
        .frame(height: maxHeight)
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
