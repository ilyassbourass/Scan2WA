import Foundation
import CoreGraphics

public final class PhoneNumberParser {
    public static let shared = PhoneNumberParser()

    // Regex for phone numbers: matches international and local numbers with 7 to 15 digits
    private let phoneRegex: NSRegularExpression? = {
        let pattern = #"(?:\+?[0-9]{1,4}[\s.-]?)?(?:\(?[0-9]{1,4}\)?[\s.-]?)?[0-9]{2,4}[\s.-]?[0-9]{2,4}[\s.-]?[0-9]{2,6}"#
        return try? NSRegularExpression(pattern: pattern, options: [])
    }()

    private let detector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
    }()

    private init() {}

    /// Extracts potential phone numbers from a string
    public func extractPhoneNumbers(from text: String, boundingBox: CGRect) -> [RecognizedNumber] {
        var results: [RecognizedNumber] = []
        var detectedRawStrings = Set<String>()

        // 1. Try NSDataDetector first
        if let detector = detector {
            let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                if let phoneNumber = match.phoneNumber {
                    let cleaned = cleanDigits(phoneNumber)
                    if isValidPhoneLength(cleaned) {
                        detectedRawStrings.insert(phoneNumber)
                        results.append(RecognizedNumber(
                            rawText: phoneNumber,
                            cleanNumber: cleaned,
                            formattedDisplay: formatDisplay(cleaned),
                            boundingBox: boundingBox
                        ))
                    }
                }
            }
        }

        // 2. Try Regex to catch any numbers NSDataDetector may have missed
        if let regex = phoneRegex {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                let matchString = nsString.substring(with: match.range)
                let cleaned = cleanDigits(matchString)
                if isValidPhoneLength(cleaned) && !detectedRawStrings.contains(matchString) {
                    detectedRawStrings.insert(matchString)
                    results.append(RecognizedNumber(
                        rawText: matchString,
                        cleanNumber: cleaned,
                        formattedDisplay: formatDisplay(cleaned),
                        boundingBox: boundingBox
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

    /// Verifies minimum and maximum valid phone digit length (between 7 and 15 digits)
    public func isValidPhoneLength(_ cleaned: String) -> Bool {
        let digitCount = cleaned.filter { $0.isNumber }.count
        return digitCount >= 7 && digitCount <= 15
    }

    /// Formats phone number for clean readability
    public func formatDisplay(_ cleaned: String) -> String {
        if cleaned.hasPrefix("+") {
            return cleaned
        }
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

        // If starts with local single 0 (e.g. 0612345678 in France or Morocco)
        if digitsOnly.hasPrefix("0") && !cleanPrefix.isEmpty {
            digitsOnly.removeFirst()
            return cleanPrefix + digitsOnly
        }

        // If no country code and doesn't start with 0, prepend prefix if available
        if !cleanPrefix.isEmpty && digitsOnly.count < 11 {
            return cleanPrefix + digitsOnly
        }

        return digitsOnly
    }

    /// Formats number for dialing with tel://
    public func prepareForCall(cleanNumber: String, defaultCountryPrefix: String) -> String {
        if cleanNumber.hasPrefix("+") {
            return cleanNumber
        }
        if cleanNumber.hasPrefix("0") && !defaultCountryPrefix.isEmpty {
            var digits = cleanNumber
            digits.removeFirst()
            let prefixWithPlus = defaultCountryPrefix.hasPrefix("+") ? defaultCountryPrefix : "+\(defaultCountryPrefix)"
            return prefixWithPlus + digits
        }
        return cleanNumber
    }
}
