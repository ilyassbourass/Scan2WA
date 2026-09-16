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
                    self.baseWideZoomFactor = firstSwitch // 1x Main camera equivalent (usually 2.0 on triple camera)
                }
                if let lastSwitch = switchOvers.last {
                    self.teleZoomFactor = lastSwitch // 5x Telephoto on 15 Pro Max
                }

                // Start on 1x
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
                    // 0.5x Ultra Wide lens (macro capable)
                    targetFactor = device.minAvailableVideoZoomFactor
                case .oneX:
                    // 1x Main Camera
                    targetFactor = self.baseWideZoomFactor
                case .twoX:
                    // 2x Sensor Crop
                    targetFactor = min(self.baseWideZoomFactor * 2.0, device.maxAvailableVideoZoomFactor)
                case .fiveX:
                    // 5x Telephoto Camera (iPhone 15 Pro Max)
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

    public func stopSession() {
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning == true {
                self?.captureSession.stopRunning()
            }
        }
    }

    public func resumeSession() {
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning == false {
                self?.captureSession.startRunning()
            }
        }
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
            self.detectedNumbers = numbers

            // Add newly detected numbers to recent history
            for number in numbers {
                if !self.recentNumbers.contains(number) {
                    self.recentNumbers.insert(number, at: 0)
                    if self.recentNumbers.count > 20 {
                        self.recentNumbers.removeLast()
                    }
                }
            }
        }
    }
}
