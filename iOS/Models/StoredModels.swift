import Foundation
import SwiftData
import AccountingCore

// Accounts
@Model
final class AccountModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var institutionRaw: String
    var accountType: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, institution: Institution, accountType: String = "Account") {
        self.id = id
        self.name = name
        self.institutionRaw = institution.rawValue
        self.accountType = accountType
        self.createdAt = Date()
    }

    var institution: Institution {
        Institution(rawValue: institutionRaw) ?? .other
    }
}

// Transactions
@Model
final class TransactionModel {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var bookedAt: Date
    var amountMinor: Int64
    var currency: String
    var merchant: String
    var memo: String
    var kindRaw: String
    var category: String
    var externalID: String?
    var dedupKey: String
    var transferGroupID: UUID?
    var importedAt: Date
    var sourceFile: String

    init(record: TransactionRecord, accountID: UUID, sourceFile: String) {
        self.id = record.id
        self.accountID = accountID
        self.bookedAt = record.bookedAt
        self.amountMinor = record.amountMinor
        self.currency = record.currency
        self.merchant = record.merchant
        self.memo = record.memo
        self.kindRaw = record.kind.rawValue
        self.category = record.category
        self.externalID = record.externalID
        self.dedupKey = record.dedupKey
        self.transferGroupID = nil
        self.importedAt = Date()
        self.sourceFile = sourceFile
    }

    var kind: TransactionKind {
        TransactionKind(rawValue: kindRaw) ?? .unknown
    }

    // plain copy for the calculations in AccountingCore
    var record: TransactionRecord {
        TransactionRecord(
            id: id,
            bookedAt: bookedAt,
            amountMinor: amountMinor,
            currency: currency,
            merchant: merchant,
            memo: memo,
            kind: kind,
            category: category,
            externalID: externalID,
            dedupKey: dedupKey
        )
    }
}

// Import history
@Model
final class ImportBatchModel {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var filename: String
    var date: Date
    var totalRows: Int
    var inserted: Int
    var duplicates: Int
    var rejected: Int
    var issues: String

    init(accountID: UUID, filename: String, totalRows: Int, inserted: Int, duplicates: Int, rejected: Int, issues: String) {
        self.id = UUID()
        self.accountID = accountID
        self.filename = filename
        self.date = Date()
        self.totalRows = totalRows
        self.inserted = inserted
        self.duplicates = duplicates
        self.rejected = rejected
        self.issues = issues
    }
}

// Budgets
@Model
final class BudgetModel {
    @Attribute(.unique) var id: UUID
    var category: String
    var monthlyLimitMinor: Int64

    init(category: String, monthlyLimitMinor: Int64) {
        self.id = UUID()
        self.category = category
        self.monthlyLimitMinor = monthlyLimitMinor
    }
}
