import Foundation

public enum MoneyFormat {
    case automatic
    case dotDecimal  // broker style, e.g. 3.910000
}

// Money
public enum MoneyParser {

    // returns cents, so 1.234,56 € becomes 123456
    public static func minorUnits(_ input: String, format: MoneyFormat = .automatic) -> Int64? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // Sign
        var negative = value.hasPrefix("(") && value.hasSuffix(")")
        if negative {
            value = String(value.dropFirst().dropLast())
        }
        if value.hasSuffix("-") {
            negative = true
            value.removeLast()
        }

        value = value
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")

        if value.hasPrefix("-") {
            negative = true
            value.removeFirst()
        }
        if value.hasPrefix("+") {
            value.removeFirst()
        }

        let onlyNumberCharacters = value.allSatisfy { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }
        guard !value.isEmpty, onlyNumberCharacters else { return nil }

        // Decimal separator
        let lastComma = value.lastIndex(of: ",")
        let lastDot = value.lastIndex(of: ".")
        var decimalSeparator: Character?

        if let lastComma, let lastDot {
            decimalSeparator = lastComma > lastDot ? "," : "."
        } else if format == .dotDecimal, lastDot != nil {
            decimalSeparator = "."
        } else if let position = lastComma ?? lastDot {
            // one or two digits after it means decimals, three means thousands (1.234)
            let digitsAfter = value.distance(from: value.index(after: position), to: value.endIndex)
            decimalSeparator = (digitsAfter == 1 || digitsAfter == 2) ? value[position] : nil
        }

        let digits = value.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        var normalized = digits
        if let decimalSeparator, let position = value.lastIndex(of: decimalSeparator) {
            let before = value[..<position].filter { $0.isNumber }
            let after = value[value.index(after: position)...].filter { $0.isNumber }
            normalized = "\(before).\(after)"
        }

        // Cents
        let signed = (negative ? "-" : "") + normalized
        let decimal = NSDecimalNumber(string: signed, locale: Locale(identifier: "en_US_POSIX"))
        guard decimal != NSDecimalNumber.notANumber else { return nil }

        let rounding = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let cents = decimal.multiplying(by: 100).rounding(accordingToBehavior: rounding)
        return Int64(cents.stringValue)
    }
}

// Dates
public enum BookingDateParser {

    private static let isoWithFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let formats = [
        "dd.MM.yyyy",
        "yyyy-MM-dd",
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "yyyy/MM/dd",
        "dd.MM.yyyy HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss"
    ]

    private static let formatters: [DateFormatter] = formats.map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter
    }

    public static func parse(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let date = isoWithFractions.date(from: value) {
            return date
        }
        if let date = iso.date(from: value) {
            return date
        }
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

// Keys
public enum StableKey {

    // FNV-1a, only for finding duplicates, not for security
    public static func hash(_ string: String) -> String {
        var result: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            result ^= UInt64(byte)
            result = result &* 1_099_511_628_211
        }
        return String(result, radix: 16)
    }
}
