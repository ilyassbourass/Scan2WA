import SwiftUI
import VisionKit
import AVFoundation

public struct DataScannerView: UIViewControllerRepresentable {
    @Binding public var detectedNumbers: [RecognizedNumber]
    @Binding public var isScanning: Bool
    @Binding public var isTorchOn: Bool
    @Binding public var zoomFactor: CGFloat
    public let onSelectNumber: (RecognizedNumber) -> Void

    public init(
        detectedNumbers: Binding<[RecognizedNumber]>,
        isScanning: Binding<Bool>,
        isTorchOn: Binding<Bool>,
        zoomFactor: Binding<CGFloat>,
        onSelectNumber: @escaping (RecognizedNumber) -> Void
    ) {
        self._detectedNumbers = detectedNumbers
        self._isScanning = isScanning
        self._isTorchOn = isTorchOn
        self._zoomFactor = zoomFactor
        self.onSelectNumber = onSelectNumber
    }

    public func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .text(textContentType: .telephoneNumber)
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner

        if isScanning {
            try? scanner.startScanning()
        }

        return scanner
    }

    public func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }

        // Handle torch toggle
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
        }

        // Handle zoom factor
        if uiViewController.zoomFactor != zoomFactor && zoomFactor >= 1.0 {
            uiViewController.zoomFactor = zoomFactor
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerView
        weak var scanner: DataScannerViewController?

        init(_ parent: DataScannerView) {
            self.parent = parent
        }

        // Direct tap on any highlighted number on the camera screen
        public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                let parsed = PhoneNumberParser.shared.extractPhoneNumbers(from: text.transcript, boundingBox: .zero)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                if let first = parsed.first {
                    DispatchQueue.main.async {
                        self.parent.onSelectNumber(first)
                    }
                } else {
                    let cleaned = PhoneNumberParser.shared.cleanDigits(text.transcript)
                    let fallback = RecognizedNumber(
                        rawText: text.transcript,
                        cleanNumber: cleaned,
                        formattedDisplay: cleaned,
                        boundingBox: .zero
                    )
                    DispatchQueue.main.async {
                        self.parent.onSelectNumber(fallback)
                    }
                }
            }
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        public func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems)
        }

        private func processItems(_ items: [RecognizedItem]) {
            var extractedList: [RecognizedNumber] = []
            var seenKeys = Set<String>()

            for item in items {
                if case .text(let text) = item {
                    let numbers = PhoneNumberParser.shared.extractPhoneNumbers(from: text.transcript, boundingBox: .zero)
                    for num in numbers {
                        if !seenKeys.contains(num.cleanNumber) {
                            seenKeys.insert(num.cleanNumber)
                            extractedList.append(num)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.parent.detectedNumbers = extractedList
            }
        }
    }
}
