import Foundation
import SwiftData
import AccountingCore

struct ImportResult {
    let inserted: Int
    let duplicates: Int
    let rejected: Int
    let issues: [String]

    var message: String {
        var text = "New: \(inserted) · Duplicates: \(duplicates) · Rejected: \(rejected)"

        if !issues.isEmpty {
            text += "\n\n" + issues.prefix(5).joined(separator: "\n")
        }
        if issues.count > 5 {
            text += "\n… more notes in the import history."
        }
        return text
    }
}

@MainActor
enum ImportService {

    static func importFile(at url: URL, for account: AccountModel, context: ModelContext) throws -> ImportResult {
        // files from the Files app need security scoped access
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let parsed = try CSVImportMapper.parse(data, institution: account.institution, accountKey: account.id.uuidString)

        // Duplicates
        let allTransactions = try context.fetch(FetchDescriptor<TransactionModel>())
        var knownKeys = Set(allTransactions.filter { $0.accountID == account.id }.map(\.dedupKey))
        var inserted = 0
        var duplicates = 0

        for record in parsed.records {
            if knownKeys.contains(record.dedupKey) {
                duplicates += 1
                continue
            }

            context.insert(TransactionModel(record: record, accountID: account.id, sourceFile: url.lastPathComponent))
            knownKeys.insert(record.dedupKey)
            inserted += 1
        }

        // History
        let rejected = parsed.totalRows - parsed.records.count
        let history = ImportBatchModel(
            accountID: account.id,
            filename: url.lastPathComponent,
            totalRows: parsed.totalRows,
            inserted: inserted,
            duplicates: duplicates,
            rejected: rejected,
            issues: parsed.issues.joined(separator: "\n")
        )
        context.insert(history)
        try context.save()

        return ImportResult(inserted: inserted, duplicates: duplicates, rejected: rejected, issues: parsed.issues)
    }
}
