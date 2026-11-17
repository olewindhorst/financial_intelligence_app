import Foundation

// Account providers
public enum Institution: String, Codable, CaseIterable, Identifiable, Sendable {
    case bank = "Bank"
    case broker = "Broker"
    case other = "Other"

    public var id: String { rawValue }
}

// Transaction kinds
public enum TransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case income
    case expense
    case dividend
    case interest
    case fee
    case tax
    case investmentBuy
    case investmentSell
    case transfer
    case unknown

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .dividend: "Dividend"
        case .interest: "Interest"
        case .fee: "Fee"
        case .tax: "Tax"
        case .investmentBuy: "Security purchase"
        case .investmentSell: "Security sale"
        case .transfer: "Transfer"
        case .unknown: "Unclear"
        }
    }

    // trades and transfers between own accounts are not income or spending
    public var isOperatingCashflow: Bool {
        switch self {
        case .income, .expense, .dividend, .interest, .fee, .tax: true
        default: false
        }
    }
}

// Transaction
public struct TransactionRecord: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bookedAt: Date
    public var amountMinor: Int64
    public var currency: String
    public var merchant: String
    public var memo: String
    public var kind: TransactionKind
    public var category: String
    public var externalID: String?
    public var dedupKey: String

    public init(
        id: UUID = UUID(),
        bookedAt: Date,
        amountMinor: Int64,
        currency: String = "EUR",
        merchant: String,
        memo: String,
        kind: TransactionKind,
        category: String,
        externalID: String? = nil,
        dedupKey: String = ""
    ) {
        self.id = id
        self.bookedAt = bookedAt
        self.amountMinor = amountMinor
        self.currency = currency
        self.merchant = merchant
        self.memo = memo
        self.kind = kind
        self.category = category
        self.externalID = externalID
        self.dedupKey = dedupKey
    }
}

// Import
public enum ImportError: Error, LocalizedError, Equatable {
    case unreadableFile
    case unsupportedColumns
    case emptyFile

    public var errorDescription: String? {
        switch self {
        case .unreadableFile: "The file could not be read as CSV text."
        case .unsupportedColumns: "CSV columns not recognised. Required: booking date and amount."
        case .emptyFile: "The CSV file is empty."
        }
    }
}

public struct ParsedImport: Sendable {
    public var records: [TransactionRecord]
    public var totalRows: Int
    public var issues: [String]
    public var headerColumns: [String]

    public init(records: [TransactionRecord], totalRows: Int, issues: [String], headerColumns: [String]) {
        self.records = records
        self.totalRows = totalRows
        self.issues = issues
        self.headerColumns = headerColumns
    }
}
