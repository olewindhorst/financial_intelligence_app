import SwiftUI
import SwiftData
import Charts
import AccountingCore

struct DashboardView: View {
    @Query(sort: \TransactionModel.bookedAt, order: .reverse) private var transactions: [TransactionModel]
    @Query private var accounts: [AccountModel]
    @State private var selectedMonth = Date()

    // Data
    private var monthRecords: [TransactionRecord] {
        let interval = FinanceAnalytics.monthInterval(containing: selectedMonth)
        return transactions.map(\.record).filter { interval.contains($0.bookedAt) }
    }

    private var lastSixMonths: [MonthBucket] {
        Array(FinanceAnalytics.months(transactions.map(\.record)).suffix(6))
    }

    var body: some View {
        let totals = FinanceAnalytics.summary(monthRecords)
        let breakdown = FinanceAnalytics.expensesByCategory(monthRecords)
        let expenseTotal = breakdown.reduce(0) { $0 + $1.amountMinor }
        let buckets = lastSixMonths

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    monthSwitcher
                    netCashflow(totals)

                    HStack(spacing: 12) {
                        MetricTile(title: "Income", amount: totals.incomeMinor, symbol: "arrow.down.left", tint: .primary)
                        MetricTile(title: "Expenses", amount: totals.expenseMinor, symbol: "arrow.up.right", tint: .primary)
                    }

                    if let rate = totals.savingsRate {
                        HStack {
                            Label("Savings rate", systemImage: "percent")
                            Spacer()
                            Text(rate.formatted(.percent.precision(.fractionLength(1))))
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }

                    if !buckets.isEmpty {
                        monthlyChart(buckets)
                    }

                    if !breakdown.isEmpty {
                        categoryList(breakdown, total: expenseTotal)
                    }

                    if accounts.isEmpty {
                        ContentUnavailableView(
                            "No accounts yet",
                            systemImage: "tray",
                            description: Text("Add your first account in the Accounts tab or load the demo data under More.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Overview")
        }
    }

    // Header
    private var monthSwitcher: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")

            Spacer()
            Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
        }
        .buttonStyle(.borderless)
    }

    private func netCashflow(_ totals: CashflowSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Net cashflow this month")
                .foregroundStyle(.secondary)
            Text(totals.netMinor.euro)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("No account balances or portfolio values")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Chart
    private func monthlyChart(_ buckets: [MonthBucket]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last six months")
                .font(.title3.weight(.semibold))

            Chart {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("Month", bucket.id),
                        y: .value("Income", Double(bucket.incomeMinor) / 100)
                    )
                    .foregroundStyle(.green.gradient)
                    .position(by: .value("Type", "Income"))

                    BarMark(
                        x: .value("Month", bucket.id),
                        y: .value("Expenses", Double(bucket.expenseMinor) / 100)
                    )
                    .foregroundStyle(.blue.gradient)
                    .position(by: .value("Type", "Expenses"))
                }
            }
            .chartYAxisLabel("EUR")
            .frame(height: 200)

            HStack(spacing: 18) {
                Label("Income", systemImage: "circle.fill")
                    .foregroundStyle(.green)
                Label("Expenses", systemImage: "circle.fill")
                    .foregroundStyle(.blue)
            }
            .font(.caption)
        }
    }

    // Categories
    private func categoryList(_ breakdown: [(category: String, amountMinor: Int64)], total: Int64) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Expenses by category")
                .font(.title3.weight(.semibold))

            ForEach(breakdown.prefix(5), id: \.category) { item in
                VStack(spacing: 6) {
                    HStack {
                        Text(item.category)
                            .font(.subheadline)
                        Spacer()
                        Text(item.amountMinor.euro)
                            .font(.subheadline.weight(.medium))
                    }
                    ProgressView(value: total == 0 ? 0 : Double(item.amountMinor) / Double(total))
                        .tint(Color.secondary)
                }
            }
        }
    }

    private func moveMonth(by months: Int) {
        if let newDate = FinanceAnalytics.utcCalendar.date(byAdding: .month, value: months, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}
