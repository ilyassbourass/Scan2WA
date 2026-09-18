import Foundation
import SwiftUI

public enum DeliveryStatus: String, Codable, CaseIterable, Identifiable {
    case livre = "Livré"
    case reporte = "Reporté"
    case annule = "Annulé"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .livre: return "checkmark.circle.fill"
        case .reporte: return "clock.arrow.circlepath"
        case .annule: return "xmark.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .livre: return Color(red: 0.15, green: 0.78, blue: 0.35) // Emerald Green
        case .reporte: return Color(red: 1.0, green: 0.65, blue: 0.0) // Warm Orange / Amber
        case .annule: return Color(red: 0.95, green: 0.25, blue: 0.25) // Vibrant Red
        }
    }

    public var backgroundColor: Color {
        color.opacity(0.18)
    }
}

public struct PackageModel: Identifiable, Codable, Equatable {
    public let id: UUID
    public var phoneNumber: String
    public var cleanNumber: String
    public var photoFileName: String
    public var locationLink: String?
    public var notes: String?
    public var createdAt: Date
    public var status: DeliveryStatus

    public init(
        id: UUID = UUID(),
        phoneNumber: String,
        cleanNumber: String,
        photoFileName: String,
        locationLink: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        status: DeliveryStatus = .livre
    ) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.cleanNumber = cleanNumber
        self.photoFileName = photoFileName
        self.locationLink = locationLink
        self.notes = notes
        self.createdAt = createdAt
        self.status = status
    }

    // Custom decoding for backward compatibility with v1.8.0
    private enum CodingKeys: String, CodingKey {
        case id, phoneNumber, cleanNumber, photoFileName, locationLink, notes, createdAt, status, isDelivered
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        cleanNumber = try container.decode(String.self, forKey: .cleanNumber)
        photoFileName = try container.decode(String.self, forKey: .photoFileName)
        locationLink = try container.decodeIfPresent(String.self, forKey: .locationLink)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        if let decodedStatus = try container.decodeIfPresent(DeliveryStatus.self, forKey: .status) {
            status = decodedStatus
        } else if let isDelivered = try container.decodeIfPresent(Bool.self, forKey: .isDelivered) {
            status = isDelivered ? .livre : .reporte
        } else {
            status = .livre
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(cleanNumber, forKey: .cleanNumber)
        try container.encode(photoFileName, forKey: .photoFileName)
        try container.encodeIfPresent(locationLink, forKey: .locationLink)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
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
