import Foundation
import CoreGraphics

public struct RecognizedNumber: Identifiable, Equatable, Hashable {
    public let id: UUID
    public let rawText: String
    public let cleanNumber: String
    public let formattedDisplay: String
    public let boundingBox: CGRect
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        rawText: String,
        cleanNumber: String,
        formattedDisplay: String,
        boundingBox: CGRect,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.rawText = rawText
        self.cleanNumber = cleanNumber
        self.formattedDisplay = formattedDisplay
        self.boundingBox = boundingBox
        self.timestamp = timestamp
    }

    public static func == (lhs: RecognizedNumber, rhs: RecognizedNumber) -> Bool {
        lhs.cleanNumber == rhs.cleanNumber
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cleanNumber)
    }
}
