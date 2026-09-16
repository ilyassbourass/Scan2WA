import Foundation
import AVFoundation
import SwiftUI
import Combine

public final class CameraManager: NSObject, ObservableObject {
    @Published public var detectedNumbers: [RecognizedNumber] = []
    @Published public var recentNumbers: [RecognizedNumber] = []
    @Published public var isTorchOn: Bool = false
    @Published public var currentZoomPreset: ZoomPreset = .oneX
    @Published public var isPaused: Bool = false
    @Published public var hasCameraPermission: Bool = true
    @Published public var isMacroActive: Bool = false

    public weak var previewLayer: AVCaptureVideoPreviewLayer?

    private var trackedNumbersMap: [String: RecognizedNumber] = [:]
    private var trackedRects: [String: CGRect] = [:]

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
                        connection.videoOrientation = .portrait
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

    public func togglePause() {
        isPaused.toggle()
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
        guard !isPaused else { return }

        VisionTextRecognizer.shared.processFrame(sampleBuffer) { [weak self] numbers in
            guard let self = self else { return }
            self.updateDetectionsWithTracking(numbers)
        }
    }
}
