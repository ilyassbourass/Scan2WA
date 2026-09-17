import Foundation
import AVFoundation
import SwiftUI
import Combine
import CoreImage

public final class CameraManager: NSObject, ObservableObject {
    @Published public var detectedNumbers: [RecognizedNumber] = []
    @Published public var recentNumbers: [RecognizedNumber] = []
    @Published public var isTorchOn: Bool = false
    @Published public var currentZoomPreset: ZoomPreset = .oneX
    @Published public var isPaused: Bool = false
    @Published public var hasCameraPermission: Bool = true
    @Published public var isMacroActive: Bool = false
    @Published public var capturedImage: UIImage? = nil
    @Published public var autoFreeze: Bool = true

    public weak var previewLayer: AVCaptureVideoPreviewLayer?

    private var trackedNumbersMap: [String: RecognizedNumber] = [:]
    private var trackedRects: [String: CGRect] = [:]
    private var freezeWorkItem: DispatchWorkItem?
    private var isFreezing: Bool = false
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var latestPixelBuffer: CVPixelBuffer?

    public enum ZoomPreset: String, CaseIterable, Identifiable {
        case macro = "0.5x"
        case oneX = "1x"
        case twoX = "2x"
        case fiveX = "5x"

        public var id: String { rawValue }
    }

    public let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.scan2wa.cameraSessionQueue")
    private var baseWideZoomFactor: CGFloat = 2.0
    private var teleZoomFactor: CGFloat = 10.0

    public override init() {
        super.init()
        checkPermissions()
    }

    public func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasCameraPermission = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            hasCameraPermission = false
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            // Setup camera: Prioritize Triple Camera for iPhone 15 Pro Max auto-switching & macro
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInTripleCamera,
                    .builtInDualWideCamera,
                    .builtInWideAngleCamera
                ],
                mediaType: .video,
                position: .back
            )

            guard let device = discovery.devices.first else {
                self.captureSession.commitConfiguration()
                return
            }

            self.videoDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                // Configure Video Output
                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                    ]
                    self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.scan2wa.videoOutputQueue"))
                    self.captureSession.addOutput(self.videoOutput)

                    if let connection = self.videoOutput.connection(with: .video) {
                        if #available(iOS 17.0, *) {
                            connection.videoRotationAngle = 90
                        } else {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .standard
                        }
                    }
                }

                // Configure Auto-focus, Macro & Lens switch factors
                try device.lockForConfiguration()

                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .none
                }

                // Calculate zoom points for triple camera
                let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.floatValue) }
                if let firstSwitch = switchOvers.first {
                    self.baseWideZoomFactor = firstSwitch
                }
                if let lastSwitch = switchOvers.last {
                    self.teleZoomFactor = lastSwitch
                }

                device.videoZoomFactor = self.baseWideZoomFactor
                device.unlockForConfiguration()

            } catch {
                print("Camera configuration error: \(error)")
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    public func setZoomPreset(_ preset: ZoomPreset) {
        guard let device = videoDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let targetFactor: CGFloat
                switch preset {
                case .macro:
                    targetFactor = device.minAvailableVideoZoomFactor
                case .oneX:
                    targetFactor = self.baseWideZoomFactor
                case .twoX:
                    targetFactor = min(self.baseWideZoomFactor * 2.0, device.maxAvailableVideoZoomFactor)
                case .fiveX:
                    targetFactor = min(self.teleZoomFactor, device.maxAvailableVideoZoomFactor)
                }

                device.ramp(toVideoZoomFactor: targetFactor, withRate: 15.0)
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.currentZoomPreset = preset
                    self.isMacroActive = (preset == .macro)
                }
            } catch {
                print("Zoom error: \(error)")
            }
        }
    }

    public func toggleTorch() {
        guard let device = videoDevice, device.hasTorch else { return }
        sessionQueue.async {
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

    private var firstStableDetectionDate: Date? = nil
    private var consecutiveDetectionCount: Int = 0
    private var lastStableNumbersKey: String = ""

    public func triggerManualFreeze() {
        guard let buffer = latestPixelBuffer else { return }
        performFreeze(with: buffer)
    }

    public func resetScan() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        freezeWorkItem?.cancel()
        freezeWorkItem = nil
        isFreezing = false
        firstStableDetectionDate = nil
        consecutiveDetectionCount = 0
        lastStableNumbersKey = ""
        trackedNumbersMap.removeAll()
        trackedRects.removeAll()
        detectedNumbers.removeAll()
        latestPixelBuffer = nil
        capturedImage = nil
        isPaused = false
    }

    private func handleDetectedNumbers(_ rawDetections: [RecognizedNumber], from pixelBuffer: CVPixelBuffer) {
        updateDetectionsWithTracking(rawDetections)

        guard autoFreeze, capturedImage == nil, !isFreezing else { return }

        if rawDetections.isEmpty {
            if consecutiveDetectionCount > 0 {
                consecutiveDetectionCount -= 1
            }
            if consecutiveDetectionCount == 0 {
                firstStableDetectionDate = nil
                lastStableNumbersKey = ""
            }
            return
        }

        // Generate a sorted signature of all valid detected numbers in this frame
        let currentNumbersKey = rawDetections.map { $0.cleanNumber }.sorted().joined(separator: ",")

        if currentNumbersKey == lastStableNumbersKey {
            consecutiveDetectionCount += 1
        } else {
            // New number(s) seen: start steady aiming window
            lastStableNumbersKey = currentNumbersKey
            consecutiveDetectionCount = 1
            firstStableDetectionDate = Date()
        }

        if firstStableDetectionDate == nil {
            firstStableDetectionDate = Date()
        }

        let elapsed = Date().timeIntervalSince(firstStableDetectionDate!)

        // AUTO-FREEZE CONDITIONS:
        // Must be held steady over the phone number for at least 0.9 seconds
        // and verified across at least 8 consecutive video frames.
        // This guarantees camera focus is sharp, text is confirmed real, and avoids instant 1-frame glitches!
        if elapsed >= 0.9 && consecutiveDetectionCount >= 8 {
            performFreeze(with: pixelBuffer)
        }
    }

    public func performFreeze(with buffer: CVPixelBuffer) {
        guard !isFreezing, capturedImage == nil else { return }
        isFreezing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                DispatchQueue.main.async { self.isFreezing = false }
                return
            }

            // CRITICAL ORIENTATION CHECK:
            // If the buffer width < height, the buffer is ALREADY portrait, so orientation is .up!
            // Only if width > height (landscape) does it need .right!
            let orientation: UIImage.Orientation = (cgImage.width < cgImage.height) ? .up : .right
            let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)

            DispatchQueue.main.async {
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)

                self.capturedImage = image
                self.isPaused = true
                self.isFreezing = false
                self.freezeWorkItem = nil

                // Perform secondary high-res OCR pass on the upright frozen photo
                VisionTextRecognizer.shared.processImage(image) { [weak self] allNumbers in
                    guard let self = self else { return }
                    for n in allNumbers {
                        if self.trackedNumbersMap[n.cleanNumber] == nil {
                            self.trackedNumbersMap[n.cleanNumber] = n
                        }
                    }
                    self.detectedNumbers = Array(self.trackedNumbersMap.values)
                }
            }
        }
    }

    public func updateDetectionsWithTracking(_ rawDetections: [RecognizedNumber]) {
        guard let layer = previewLayer, layer.bounds.width > 0, layer.bounds.height > 0 else { return }

        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
        let now = Date()

        for detection in rawDetections {
            let metadataRect = detection.boundingBox.applying(transform)
            let rawScreenRect = layer.layerRectConverted(fromMetadataOutputRect: metadataRect)

            guard !rawScreenRect.isNull, !rawScreenRect.isInfinite, rawScreenRect.width > 10 else { continue }

            let key = detection.cleanNumber

            if let oldRect = trackedRects[key] {
                // Smooth tracking with Exponential Moving Average (EMA) to eliminate jitter
                let smoothedRect = CGRect(
                    x: oldRect.origin.x * 0.65 + rawScreenRect.origin.x * 0.35,
                    y: oldRect.origin.y * 0.65 + rawScreenRect.origin.y * 0.35,
                    width: oldRect.size.width * 0.75 + rawScreenRect.size.width * 0.25,
                    height: oldRect.size.height * 0.75 + rawScreenRect.size.height * 0.25
                )
                trackedRects[key] = smoothedRect

                var updated = detection
                updated.screenRect = smoothedRect
                updated.lastSeen = now
                trackedNumbersMap[key] = updated
            } else {
                trackedRects[key] = rawScreenRect

                var updated = detection
                updated.screenRect = rawScreenRect
                updated.lastSeen = now
                trackedNumbersMap[key] = updated
            }

            // Save to recent list
            if !recentNumbers.contains(detection) {
                recentNumbers.insert(detection, at: 0)
                if recentNumbers.count > 20 {
                    recentNumbers.removeLast()
                }
            }
        }

        // Prune numbers not seen for more than 0.7s to prevent sudden flickering
        trackedNumbersMap = trackedNumbersMap.filter { now.timeIntervalSince($0.value.lastSeen) < 0.7 }
        trackedRects = trackedRects.filter { trackedNumbersMap.keys.contains($0.key) }

        self.detectedNumbers = Array(trackedNumbersMap.values)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isPaused, capturedImage == nil else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Retain latest pixel buffer for silent capture
        self.latestPixelBuffer = pixelBuffer

        VisionTextRecognizer.shared.processFrame(sampleBuffer) { [weak self] numbers in
            guard let self = self, !self.isPaused, self.capturedImage == nil else { return }
            self.handleDetectedNumbers(numbers, from: pixelBuffer)
        }
    }
}

