import Foundation

public enum CSVImportMapper {

    // Column names
    private static let dateAliases = [
        "Buchungstag", "Buchungsdatum", "Valutadatum", "Datum",
        "date", "datetime", "booking_date", "value_date", "transaction_date"
    ]
    private static let amountAliases = [
        "Betrag", "Umsatz",
        "amount", "cash_amount", "total_amount", "value", "net_amount"
    ]
    private static let merchantAliases = [
        "Beguenstigter/Zahlungspflichtiger", "Begünstigter/Zahlungspflichtiger", "Auftraggeber/Empfänger",
        "Empfänger", "Zahlungspflichtiger",
        "counterparty_name", "merchant", "name", "payee"
    ]
    private static let descriptionAliases = [
        "Verwendungszweck", "Buchungstext", "Beschreibung",
        "description", "payment_reference", "memo", "purpose", "note"
    ]
    private static let currencyAliases = ["Waehrung", "Währung", "currency"]
    private static let typeAliases = ["type", "transaction_type", "Buchungsart", "Art", "transaction_kind"]
    private static let idAliases = ["transaction_id", "Umsatz-ID", "Buchungs-ID", "booking_id", "id"]

    // Import
    public static func parse(_ data: Data, institution: Institution, accountKey: String) throws -> ParsedImport {
        let text = try CSVReader.decode(data)
        let rows = CSVReader.rows(text)
        guard !rows.isEmpty else { throw ImportError.emptyFile }

        // some bank exports start with a few lines of account info before the header
        let foundHeader = rows.prefix(40).firstIndex { row in
            column(row, aliases: dateAliases) != nil && column(row, aliases: amountAliases) != nil
        }
        guard let headerIndex = foundHeader else { throw ImportError.unsupportedColumns }

        let headers = rows[headerIndex]
        guard
            let dateIndex = column(headers, aliases: dateAliases),
            let amountIndex = column(headers, aliases: amountAliases)
        else {
            throw ImportError.unsupportedColumns
        }

        let merchantIndex = column(headers, aliases: merchantAliases)
        let descriptionIndex = column(headers, aliases: descriptionAliases)
        let currencyIndex = column(headers, aliases: currencyAliases)
        let typeIndex = column(headers, aliases: typeAliases)
        let idIndex = column(headers, aliases: idAliases)

        // broker exports often write fixed decimals like 3.910000
        let isBrokerAmount = institution == .broker && clean(headers[amountIndex]) == "amount"
        let moneyFormat: MoneyFormat = isBrokerAmount ? .dotDecimal : .automatic

        var records: [TransactionRecord] = []
        var issues: [String] = []
        var seenRows: [String: Int] = [:]
        let dataRows = rows.dropFirst(headerIndex + 1)

        for (offset, row) in dataRows.enumerated() {
            let line = headerIndex + 2 + offset

            func value(_ index: Int?) -> String {
                guard let index, index < row.count else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Checks
            guard let date = BookingDateParser.parse(value(dateIndex)) else {
                issues.append("Line \(line): invalid booking date")
                continue
            }

            guard let amountMinor = MoneyParser.minorUnits(value(amountIndex), format: moneyFormat) else {
                issues.append("Line \(line): invalid amount")
                continue
            }

            let currency = value(currencyIndex).uppercased()
            if !currency.isEmpty && currency != "EUR" {
                issues.append("Line \(line): currency \(currency) not supported")
                continue
            }

            // Classification
            let merchant = value(merchantIndex)
            let memo = value(descriptionIndex)
            let externalID = value(idIndex)
            let type = value(typeIndex)
            let searchText = "\(merchant) \(memo)"
            let kind = CategoryRules.kind(type: type, text: searchText, amountMinor: amountMinor)

            // Dedup key
            let dedupKey: String
            if externalID.isEmpty {
                // two identical rows in one file can be real (two coffees on one day), so they get a counter.
                // overlapping exports from different days can still slip through, check the import history
                let timestamp = Int64(date.timeIntervalSince1970)
                let base = "row|\(institution.rawValue)|\(accountKey)|\(timestamp)|\(amountMinor)|\(merchant)|\(memo)|\(type)"
                let occurrence = (seenRows[base] ?? 0) + 1
                seenRows[base] = occurrence
                dedupKey = StableKey.hash("\(base)|\(occurrence)")
            } else {
                dedupKey = StableKey.hash("id|\(institution.rawValue)|\(accountKey)|\(externalID)|0")
            }

            records.append(
                TransactionRecord(
                    bookedAt: date,
                    amountMinor: amountMinor,
                    merchant: displayName(merchant: merchant, memo: memo),
                    memo: memo,
                    kind: kind,
                    category: CategoryRules.category(for: kind, text: searchText),
                    externalID: externalID.isEmpty ? nil : externalID,
                    dedupKey: dedupKey
                )
            )
        }

        return ParsedImport(
            records: records,
            totalRows: dataRows.count,
            issues: issues,
            headerColumns: headers
        )
    }

    // Helpers
    private static func clean(_ name: String) -> String {
        let folded = name.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "de_DE")
        )
        return String(folded.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func column(_ headers: [String], aliases: [String]) -> Int? {
        for alias in aliases {
            if let index = headers.firstIndex(where: { clean($0) == clean(alias) }) {
                return index
            }
        }
        return nil
    }

    private static func displayName(merchant: String, memo: String) -> String {
        if !merchant.isEmpty {
            return merchant
        }
        return memo.isEmpty ? "Unknown" : memo
    }
}
