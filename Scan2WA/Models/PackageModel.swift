import Foundation

public struct PackageModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var phoneNumber: String
    public var cleanNumber: String
    public var photoFileName: String
    public var locationLink: String?
    public var notes: String?
    public var createdAt: Date
    public var isDelivered: Bool

    public init(
        id: UUID = UUID(),
        phoneNumber: String,
        cleanNumber: String,
        photoFileName: String,
        locationLink: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        isDelivered: Bool = false
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.cleanNumber = cleanNumber
        self.photoFileName = photoFileName
        self.locationLink = locationLink
        self.notes = notes
        self.createdAt = createdAt
        self.isDelivered = isDelivered
    }

    /// Extracts the last 2 digits of the phone number for quick courier indexing (e.g. "73")
    public var lastTwoDigits: String {
        let digits = cleanNumber.filter { $0.isNumber }
        if digits.count >= 2 {
            return String(digits.suffix(2))
        }
        return digits.isEmpty ? "--" : digits
    }

    /// Checks if this package matches a search query
    public func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        let cleanQuery = trimmed.filter { $0.isNumber }

        // 1. Numeric search: check if ends with query digits (e.g. searching "73" matches "+212 718-644473")
        if !cleanQuery.isEmpty {
            if cleanNumber.hasSuffix(cleanQuery) {
                return true
            }
            if cleanNumber.contains(cleanQuery) {
                return true
            }
        }

        // 2. Text search: check in formatted number or notes
        if phoneNumber.localizedCaseInsensitiveContains(trimmed) {
            return true
        }
        if let notes = notes, notes.localizedCaseInsensitiveContains(trimmed) {
            return true
        }

        return false
    }
}
