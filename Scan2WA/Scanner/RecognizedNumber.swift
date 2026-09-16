import Foundation
import CoreGraphics

public struct RecognizedNumber: Identifiable, Equatable, Hashable {
    // Stable identifier using the clean number so SwiftUI does not re-animate on every frame
    public var id: String { cleanNumber }
    public let rawText: String
    public let cleanNumber: String
    public let formattedDisplay: String
    public var boundingBox: CGRect
    public var screenRect: CGRect
    public var lastSeen: Date

    public init(
        rawText: String,
        cleanNumber: String,
        formattedDisplay: String,
        boundingBox: CGRect,
        screenRect: CGRect = .zero,
        lastSeen: Date = Date()
    ) {
        self.rawText = rawText
        self.cleanNumber = cleanNumber
        self.formattedDisplay = formattedDisplay
        self.boundingBox = boundingBox
        self.screenRect = screenRect
        self.lastSeen = lastSeen
    }

    public static func == (lhs: RecognizedNumber, rhs: RecognizedNumber) -> Bool {
        lhs.cleanNumber == rhs.cleanNumber
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(cleanNumber)
    }
}
