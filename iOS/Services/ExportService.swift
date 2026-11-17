import Foundation

// writes a CSV into the temp folder, sharing is up to the user
enum ExportService {

    static func create(transactions: [TransactionModel], accounts: [AccountModel]) throws -> URL {
        let accountNames = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.name) })
        let dateFormatter = ISO8601DateFormatter()

        let header = "account;date;amount_eur;kind;category;merchant;memo;source_file;source_id"
        let lines = transactions
            .sorted { $0.bookedAt < $1.bookedAt }
            .map { transaction in
                [
                    field(accountNames[transaction.accountID] ?? "Unknown"),
                    field(dateFormatter.string(from: transaction.bookedAt)),
                    euroAmount(transaction.amountMinor),
                    field(transaction.kindRaw),
                    field(transaction.category),
                    field(transaction.merchant),
                    field(transaction.memo),
                    field(transaction.sourceFile),
                    field(transaction.externalID ?? "")
                ]
                .joined(separator: ";")
            }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("accounting_export_\(UUID().uuidString).csv")
        let content = header + "\n" + lines.joined(separator: "\n") + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // Helpers
    private static func euroAmount(_ minor: Int64) -> String {
        let sign = minor < 0 ? "-" : ""
        let cents = minor.magnitude % 100
        let euros = minor.magnitude / 100
        let centText = cents < 10 ? "0\(cents)" : "\(cents)"
        return "\(sign)\(euros).\(centText)"
    }

    private static func field(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        // stop Excel/Numbers from running merchant names like "=..." as formulas
        let startsLikeFormula = "=+-@\t".contains(singleLine.first ?? " ")
        let safe = startsLikeFormula ? "'" + singleLine : singleLine

        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
