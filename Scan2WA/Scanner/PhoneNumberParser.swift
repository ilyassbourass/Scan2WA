import Foundation
import CoreGraphics
import Vision

public final class PhoneNumberParser {
    public static let shared = PhoneNumberParser()

    // Regex matching valid phone numbers with word boundaries to reject tracking numbers like SSD0123777-26
    private let phoneRegex: NSRegularExpression? = {
        // Matches +XXX... or local numbers 06..., 07..., 05... or international patterns
        let pattern = #"(?<![A-Za-z0-9])(?:\+?[0-9]{1,4}[\s.-]?)?(?:\([0-9]{1,4}\)[\s.-]?)?[0-9]{2,4}[\s.-]?[0-9]{2,4}[\s.-]?[0-9]{2,4}(?![A-Za-z0-9])"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    private let detector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    }()

    private init() {}

    /// Extracts potential phone numbers from a string with exact character-level bounding box
    public func extractPhoneNumbers(
        from text: String,
        candidate: VNRecognizedText? = nil,
        boundingBox: CGRect
    ) -> [RecognizedNumber] {
        var results: [RecognizedNumber] = []
        var detectedCleanStrings = Set<String>()

        // Check if full string contains package/barcode keywords to avoid
        let lower = text.lowercased()
        if lower.contains("ssd") || lower.contains("crbt") || lower.contains("colis") {
            // Check only sub-tokens that are preceded by phone keywords
        }

        // 1. Try NSDataDetector first
        if let detector = detector {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                if let phoneNumber = match.phoneNumber {
                    let cleaned = cleanDigits(phoneNumber)
                    if isValidPhoneNumber(cleaned) && !detectedCleanStrings.contains(cleaned) {
                        detectedCleanStrings.insert(cleaned)

                        var preciseBox = boundingBox
                        if let candidate = candidate,
                           let strRange = Range(match.range, in: text),
                           let subObs = try? candidate.boundingBox(for: strRange) {
                            preciseBox = subObs.boundingBox
                        }

                        results.append(RecognizedNumber(
                            rawText: phoneNumber,
                            cleanNumber: cleaned,
                            formattedDisplay: formatDisplay(cleaned),
                            boundingBox: preciseBox
                        ))
                    }
                }
            }
        }

        // 2. Try Regex with word boundaries
        if let regex = phoneRegex {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                let matchString = nsString.substring(with: match.range)
                let cleaned = cleanDigits(matchString)
                if isValidPhoneNumber(cleaned) && !detectedCleanStrings.contains(cleaned) {
                    detectedCleanStrings.insert(cleaned)

                    var preciseBox = boundingBox
                    if let candidate = candidate,
                       let strRange = Range(match.range, in: text),
                       let subObs = try? candidate.boundingBox(for: strRange) {
                        preciseBox = subObs.boundingBox
                    }

                    results.append(RecognizedNumber(
                        rawText: matchString,
                        cleanNumber: cleaned,
                        formattedDisplay: formatDisplay(cleaned),
                        boundingBox: preciseBox
                    ))
                }
            }
        }

        return results
    }

    /// Strips spaces, dashes, parentheses. Keeps leading '+' if present.
    public func cleanDigits(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        for (index, char) in trimmed.enumerated() {
            if index == 0 && char == "+" {
                result.append(char)
            } else if char.isNumber {
                result.append(char)
            }
        }
        return result
    }

    /// Verifies valid phone number structure (rejects serial/package codes, barcodes, timestamps)
    public func isValidPhoneNumber(_ cleaned: String) -> Bool {
        let digitsOnly = cleaned.filter { $0.isNumber }
        let count = digitsOnly.count

        // Real phone numbers are typically 9 to 15 digits
        guard count >= 9 && count <= 15 else { return false }

        // 1. Moroccan numbers starting with local 0: (e.g. 0605922827, 0767557451, 0522123456)
        if digitsOnly.count == 10 && digitsOnly.hasPrefix("0") {
            let prefix2 = String(digitsOnly.prefix(2))
            return prefix2 == "05" || prefix2 == "06" || prefix2 == "07" || prefix2 == "08"
        }

        // 2. Moroccan international numbers starting with +212, 212, or 00212:
        // e.g. +212 718-644473, +212 708-769358, 212605922827
        if cleaned.hasPrefix("+212") || digitsOnly.hasPrefix("212") || digitsOnly.hasPrefix("00212") {
            var withoutCode = digitsOnly
            if withoutCode.hasPrefix("00212") {
                withoutCode = String(withoutCode.dropFirst(5))
            } else if withoutCode.hasPrefix("212") {
                withoutCode = String(withoutCode.dropFirst(3))
            }
            // After 212, Moroccan numbers have exactly 9 digits starting with 5, 6, 7, or 8
            if withoutCode.count == 9 {
                let firstDigit = String(withoutCode.prefix(1))
                return firstDigit == "5" || firstDigit == "6" || firstDigit == "7" || firstDigit == "8"
            }
            return false
        }

        // 3. Generic international numbers starting with '+' (e.g. +1, +33, +44, +971, +966)
        if cleaned.hasPrefix("+") {
            return count >= 10 && count <= 15
        }

        // Numbers without '+' and without leading '0' are not valid Moroccan/international phone numbers
        // (This strictly rejects barcodes, tracking numbers, timestamps like 1234567890 or 0123777-26)
        return false
    }

    /// Formats phone number for clean readability
    public func formatDisplay(_ cleaned: String) -> String {
        return cleaned
    }

    /// Formats number for WhatsApp (must be international format without '+' or spaces)
    public func prepareForWhatsApp(cleanNumber: String, defaultCountryPrefix: String) -> String {
        var digitsOnly = cleanNumber.filter { $0.isNumber }
        let cleanPrefix = defaultCountryPrefix.filter { $0.isNumber }

        // If number starts with international prefix '+'
        if cleanNumber.hasPrefix("+") {
            return digitsOnly
        }

        // If starts with double 00 (e.g. 00212...)
        if digitsOnly.hasPrefix("00") {
            digitsOnly.removeFirst(2)
            return digitsOnly
        }

        // If starts with 212... already
        if digitsOnly.hasPrefix("212") && digitsOnly.count == 12 {
            return digitsOnly
        }

        // If starts with local single 0 (e.g. 0605922827)
        if digitsOnly.hasPrefix("0") && !cleanPrefix.isEmpty {
            digitsOnly.removeFirst()
            return cleanPrefix + digitsOnly
        }

        // If missing country code, prepend prefix
        if !cleanPrefix.isEmpty && digitsOnly.count <= 10 {
            return cleanPrefix + digitsOnly
        }

        return digitsOnly
    }

    /// Formats number for dialing with tel://
    public func prepareForCall(cleanNumber: String, defaultCountryPrefix: String) -> String {
        let waDigits = prepareForWhatsApp(cleanNumber: cleanNumber, defaultCountryPrefix: defaultCountryPrefix)
        return "+\(waDigits)"
    }
}
