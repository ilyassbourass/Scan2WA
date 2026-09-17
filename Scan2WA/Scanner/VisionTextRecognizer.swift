import Foundation
import UIKit
import Vision
import CoreMedia
import CoreGraphics
import ImageIO

public final class VisionTextRecognizer {
    public static let shared = VisionTextRecognizer()

    private let parser = PhoneNumberParser.shared
    private var isProcessing = false
    private let processingQueue = DispatchQueue(label: "com.scan2wa.visionQueue", qos: .userInitiated)

    private init() {}

    public func processFrame(
        _ sampleBuffer: CMSampleBuffer,
        completion: @escaping ([RecognizedNumber]) -> Void
    ) {
        guard !isProcessing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessing = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self, error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var detectedNumbers: [RecognizedNumber] = []

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let string = topCandidate.string

                    // Check for phone numbers in candidate text
                    let parsed = self.parser.extractPhoneNumbers(
                        from: string,
                        boundingBox: observation.boundingBox
                    )
                    detectedNumbers.append(contentsOf: parsed)
                }

                // De-duplicate results while keeping unique numbers
                var seen = Set<String>()
                let uniqueNumbers = detectedNumbers.filter { item in
                    if seen.contains(item.cleanNumber) {
                        return false
                    } else {
                        seen.insert(item.cleanNumber)
                        return true
                    }
                }

                DispatchQueue.main.async {
                    completion(uniqueNumbers)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "fr-FR", "es-ES", "ar"]

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            try? handler.perform([request])
        }
    }

    /// Performs an accurate high-resolution OCR pass on a captured still photo
    public func processImage(
        _ image: UIImage,
        completion: @escaping ([RecognizedNumber]) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let orientation: CGImagePropertyOrientation
        switch image.imageOrientation {
        case .up: orientation = .up
        case .upMirrored: orientation = .upMirrored
        case .down: orientation = .down
        case .downMirrored: orientation = .downMirrored
        case .left: orientation = .left
        case .leftMirrored: orientation = .leftMirrored
        case .right: orientation = .right
        case .rightMirrored: orientation = .rightMirrored
        @unknown default: orientation = .up
        }

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self, error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var detectedNumbers: [RecognizedNumber] = []

                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let string = topCandidate.string

                    let parsed = self.parser.extractPhoneNumbers(
                        from: string,
                        boundingBox: observation.boundingBox
                    )
                    detectedNumbers.append(contentsOf: parsed)
                }

                var seen = Set<String>()
                let uniqueNumbers = detectedNumbers.filter { item in
                    if seen.contains(item.cleanNumber) {
                        return false
                    } else {
                        seen.insert(item.cleanNumber)
                        return true
                    }
                }

                DispatchQueue.main.async {
                    completion(uniqueNumbers)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "fr-FR", "es-ES", "ar"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try? handler.perform([request])
        }
    }
}
