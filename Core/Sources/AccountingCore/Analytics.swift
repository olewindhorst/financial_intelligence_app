import Foundation

public struct CashflowSummary: Equatable, Sendable {
    public var incomeMinor: Int64
    public var expenseMinor: Int64

    public var netMinor: Int64 {
        incomeMinor - expenseMinor
    }

    public var savingsRate: Double? {
        guard incomeMinor > 0 else { return nil }
        return Double(netMinor) / Double(incomeMinor)
    }
}

public struct MonthBucket: Equatable, Identifiable, Sendable {
    public var year: Int
    public var month: Int
    public var incomeMinor: Int64
    public var expenseMinor: Int64

    public var id: String {
        "\(year)-\(month)"
    }
}

public enum FinanceAnalytics {

    // Calendar
    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    public static func monthInterval(containing date: Date) -> DateInterval {
        utcCalendar.dateInterval(of: .month, for: date)!
    }

    // Cashflow
    public static func summary(_ transactions: [TransactionRecord], interval: DateInterval? = nil) -> CashflowSummary {
        var income: Int64 = 0
        var expense: Int64 = 0

        for transaction in transactions where transaction.kind.isOperatingCashflow {
            if let interval, !interval.contains(transaction.bookedAt) {
                continue
            }

            if transaction.amountMinor > 0 {
                income += transaction.amountMinor
            } else {
                expense -= transaction.amountMinor
            }
        }

        return CashflowSummary(incomeMinor: income, expenseMinor: expense)
    }

    public static func months(_ transactions: [TransactionRecord]) -> [MonthBucket] {
        let calendar = utcCalendar
        var buckets: [String: MonthBucket] = [:]

        for transaction in transactions where transaction.kind.isOperatingCashflow {
            let parts = calendar.dateComponents([.year, .month], from: transaction.bookedAt)
            guard let year = parts.year, let month = parts.month else { continue }

            let key = "\(year)-\(month)"
            var bucket = buckets[key] ?? MonthBucket(year: year, month: month, incomeMinor: 0, expenseMinor: 0)

            if transaction.amountMinor > 0 {
                bucket.incomeMinor += transaction.amountMinor
            } else {
                bucket.expenseMinor -= transaction.amountMinor
            }

            buckets[key] = bucket
        }

        return buckets.values.sorted { ($0.year, $0.month) < ($1.year, $1.month) }
    }

    // Categories
    public static func expensesByCategory(
        _ transactions: [TransactionRecord],
        interval: DateInterval? = nil
    ) -> [(category: String, amountMinor: Int64)] {
        var totals: [String: Int64] = [:]

        for transaction in transactions where transaction.kind.isOperatingCashflow && transaction.amountMinor < 0 {
            if let interval, !interval.contains(transaction.bookedAt) {
                continue
            }
            totals[transaction.category, default: 0] -= transaction.amountMinor
        }

        return totals
            .map { (category: $0.key, amountMinor: $0.value) }
            .sorted { $0.amountMinor > $1.amountMinor }
    }
}

public struct TransferCandidate: Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var amountMinor: Int64
}

public enum TransferMatching {

    // only suggestions, the user has to confirm every pair
    public static func candidates(
        source: TransactionRecord,
        sourceAccount: UUID,
        others: [(account: UUID, record: TransactionRecord)],
        withinDays: Double = 3
    ) -> [TransferCandidate] {
        let maxDistance = withinDays * 86_400

        return others
            .filter { other in
                other.account != sourceAccount &&
                other.record.amountMinor == -source.amountMinor &&
                abs(other.record.bookedAt.timeIntervalSince(source.bookedAt)) <= maxDistance &&
                other.record.kind != .transfer
            }
            .map { other in
                TransferCandidate(
                    id: other.record.id,
                    date: other.record.bookedAt,
                    amountMinor: other.record.amountMinor
                )
            }
    }
}
