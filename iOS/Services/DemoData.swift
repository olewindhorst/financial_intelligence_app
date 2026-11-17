import Foundation
import SwiftData
import AccountingCore

@MainActor
enum DemoData {

    private struct Sample {
        let day: Int
        let amountMinor: Int64
        let merchant: String
        let memo: String
        let kind: TransactionKind
        let category: String
        let inDepot: Bool
    }

    // one month of synthetic bookings, repeated for the last three months
    private static let samples: [Sample] = [
        Sample(day: 3, amountMinor: 325000, merchant: "DEMO Employer", memo: "Salary", kind: .income, category: "Salary", inDepot: false),
        Sample(day: 5, amountMinor: -73000, merchant: "DEMO Landlord", memo: "Rent", kind: .expense, category: "Housing", inDepot: false),
        Sample(day: 7, amountMinor: -5790, merchant: "DEMO Supermarket", memo: "Groceries", kind: .expense, category: "Groceries", inDepot: false),
        Sample(day: 11, amountMinor: -1299, merchant: "DEMO Streaming", memo: "Subscription", kind: .expense, category: "Subscriptions", inDepot: false),
        Sample(day: 12, amountMinor: -18000, merchant: "DEMO ETF", memo: "Savings plan", kind: .investmentBuy, category: "Investments", inDepot: true),
        Sample(day: 14, amountMinor: 329, merchant: "DEMO ETF", memo: "Dividend", kind: .dividend, category: "Dividends", inDepot: true),
        Sample(day: 18, amountMinor: -2490, merchant: "DEMO Railway", memo: "Ticket", kind: .expense, category: "Transport", inDepot: false),
        Sample(day: 20, amountMinor: -10000, merchant: "DEMO Transfer", memo: "Checking to portfolio", kind: .transfer, category: "Transfers", inDepot: false),
        Sample(day: 20, amountMinor: 10000, merchant: "DEMO Transfer", memo: "Checking to portfolio", kind: .transfer, category: "Transfers", inDepot: true)
    ]

    // Add
    static func seed(context: ModelContext) throws {
        // demo accounts are clearly named, never mix them with real imports
        let accounts = try context.fetch(FetchDescriptor<AccountModel>())
        guard !accounts.contains(where: { $0.name == "DEMO · Checking" }) else { return }

        let giro = AccountModel(name: "DEMO · Checking", institution: .bank)
        let depot = AccountModel(name: "DEMO · Portfolio", institution: .broker, accountType: "Portfolio")
        context.insert(giro)
        context.insert(depot)

        let calendar = FinanceAnalytics.utcCalendar
        let today = Date()

        for monthOffset in [0, -1, -2] {
            guard let targetMonth = calendar.date(byAdding: .month, value: monthOffset, to: today) else { continue }
            let yearMonth = calendar.dateComponents([.year, .month], from: targetMonth)

            for (index, sample) in samples.enumerated() {
                let parts = DateComponents(year: yearMonth.year, month: yearMonth.month, day: min(sample.day, 28), hour: 12)
                guard let date = calendar.date(from: parts), date <= today else { continue }

                let record = TransactionRecord(
                    bookedAt: date,
                    amountMinor: sample.amountMinor,
                    merchant: sample.merchant,
                    memo: sample.memo,
                    kind: sample.kind,
                    category: sample.category,
                    dedupKey: "demo-\(monthOffset)-\(index)-\(sample.inDepot)"
                )
                let transaction = TransactionModel(
                    record: record,
                    accountID: sample.inDepot ? depot.id : giro.id,
                    sourceFile: "DEMO – synthetic test data"
                )
                context.insert(transaction)
            }
        }

        try context.save()
    }

    // Remove
    static func deleteDemo(context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<AccountModel>())
        let demoIDs = Set(accounts.filter { $0.name.hasPrefix("DEMO ·") }.map(\.id))
        let transactions = try context.fetch(FetchDescriptor<TransactionModel>())

        for transaction in transactions where demoIDs.contains(transaction.accountID) {
            context.delete(transaction)
        }
        for account in accounts where demoIDs.contains(account.id) {
            context.delete(account)
        }

        try context.save()
    }
}
