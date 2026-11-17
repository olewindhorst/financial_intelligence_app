import SwiftUI
import AccountingCore

// Formatting
extension Int64 {
    var euro: String {
        (Double(self) / 100).formatted(.currency(code: "EUR"))
    }
}

extension Date {
    var bookingLabel: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }
}

// Tiles
struct MetricTile: View {
    let title: String
    let amount: Int64
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount.euro)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// Rows
struct TransactionRow: View {
    let transaction: TransactionModel

    private var symbol: String {
        switch transaction.kind {
        case .investmentBuy, .investmentSell: "chart.line.uptrend.xyaxis"
        default: "arrow.left.arrow.right"
        }
    }

    private var amountColor: Color {
        transaction.amountMinor >= 0 ? Color.green : Color.primary
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline)
                .frame(width: 36, height: 36)
                .foregroundStyle(.secondary)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchant)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(transaction.category) · \(transaction.bookedAt.bookingLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(transaction.amountMinor.euro)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 4)
    }
}
