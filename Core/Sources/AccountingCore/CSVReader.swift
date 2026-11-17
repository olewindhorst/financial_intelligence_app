import Foundation

public enum CSVReader {

    // Encoding
    public static func decode(_ data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) {
            return text.replacingOccurrences(of: "\u{FEFF}", with: "")
        }
        if let text = String(data: data, encoding: .windowsCP1252) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw ImportError.unreadableFile
    }

    // Delimiter
    public static func delimiter(for text: String) -> Character {
        let firstLines = text.split(whereSeparator: \.isNewline).prefix(40)
        let candidates: [Character] = [";", ",", "\t"]

        // look at the header first, decimal commas in the data rows would fool the count
        for line in firstLines {
            let lower = line.lowercased()
            let hasAmount = lower.contains("betrag") || lower.contains("amount")
            let hasDate = lower.contains("buchung") || lower.contains("datum") || lower.contains("date")
            guard hasAmount && hasDate else { continue }

            let winner = candidates.max { occurrences(of: $0, in: line) < occurrences(of: $1, in: line) }
            if let winner, line.contains(winner) {
                return winner
            }
        }

        // no header found, take the first longer line with at least three separators
        for line in firstLines where line.count > 10 {
            let winner = candidates.max { occurrences(of: $0, in: line) < occurrences(of: $1, in: line) }
            if let winner, occurrences(of: winner, in: line) >= 3 {
                return winner
            }
        }

        return ";"
    }

    // Rows
    public static func rows(_ text: String, delimiter: Character? = nil) -> [[String]] {
        let separator = delimiter ?? self.delimiter(for: text)
        let characters = Array(
            text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        )

        var result: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = 0

        func finishRow() {
            row.append(field)
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                result.append(row)
            }
            row = []
            field = ""
        }

        while index < characters.count {
            let character = characters[index]

            if character == "\"" {
                let escapedQuote = quoted && index + 1 < characters.count && characters[index + 1] == "\""

                if escapedQuote {
                    field.append("\"")
                    index += 1
                } else if quoted || field.isEmpty {
                    quoted.toggle()
                } else {
                    field.append(character)
                }
            } else if character == separator && !quoted {
                row.append(field)
                field = ""
            } else if character == "\n" && !quoted {
                finishRow()
            } else {
                field.append(character)
            }

            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return result
    }

    // Helpers
    private static func occurrences(of character: Character, in line: Substring) -> Int {
        line.filter { $0 == character }.count
    }
}
