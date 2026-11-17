import SwiftUI
import SwiftData
import AccountingCore

struct TransactionsView: View {
    @Query(sort: \TransactionModel.bookedAt, order: .reverse) private var transactions: [TransactionModel]
    @Query(sort: \AccountModel.createdAt) private var accounts: [AccountModel]
    @State private var search = ""
    @State private var selectedAccount = "all"
    @State private var selectedKind = "all"

    private var filtered: [TransactionModel] {
        transactions.filter { transaction in
            let matchesAccount = selectedAccount == "all" || transaction.accountID.uuidString == selectedAccount
            let matchesKind = selectedKind == "all" || transaction.kindRaw == selectedKind
            let matchesSearch = search.isEmpty
                || transaction.merchant.localizedCaseInsensitiveContains(search)
                || transaction.memo.localizedCaseInsensitiveContains(search)
                || transaction.category.localizedCaseInsensitiveContains(search)

            return matchesAccount && matchesKind && matchesSearch
        }
    }

    var body: some View {
        let shown = filtered

        NavigationStack {
            List {
                Section {
                    Picker("Account", selection: $selectedAccount) {
                        Text("All accounts").tag("all")
                        ForEach(accounts) { account in
                            Text(account.name).tag(account.id.uuidString)
                        }
                    }
                    Picker("Kind", selection: $selectedKind) {
                        Text("All kinds").tag("all")
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.title).tag(kind.rawValue)
                        }
                    }
                }

                if shown.isEmpty {
                    ContentUnavailableView(
                        "No bookings",
                        systemImage: "tray",
                        description: Text("Import a CSV file under Accounts or change your filters.")
                    )
                } else {
                    Section("\(shown.count) bookings") {
                        ForEach(shown) { transaction in
                            NavigationLink {
                                TransactionDetailView(transaction: transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookings")
            .searchable(text: $search, prompt: "Merchant, category, purpose")
        }
    }
}

// Detail
struct TransactionDetailView: View {
    @Bindable var transaction: TransactionModel
    @Environment(\.modelContext) private var context
    @Query private var accounts: [AccountModel]
    @Query private var allTransactions: [TransactionModel]

    // same amount with opposite sign on another account within three days
    private var possibleCounterBookings: [TransactionModel] {
        allTransactions.filter { other in
            other.id != transaction.id &&
            other.accountID != transaction.accountID &&
            other.amountMinor == -transaction.amountMinor &&
            other.transferGroupID == nil &&
            abs(other.bookedAt.timeIntervalSince(transaction.bookedAt)) <= 3 * 86_400
        }
    }

    private var categoryOptions: [String] {
        Array(Set(CategoryRules.defaults + [transaction.category])).sorted()
    }

    var body: some View {
        Form {
            Section("Booking") {
                LabeledContent("Date", value: transaction.bookedAt.bookingLabel)
                LabeledContent("Amount", value: transaction.amountMinor.euro)
                LabeledContent("Account", value: accountName(transaction.accountID))
                TextField("Merchant / payee", text: $transaction.merchant)
                TextField("Purpose", text: $transaction.memo, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Classification") {
                Picker("Kind", selection: $transaction.kindRaw) {
                    ForEach(TransactionKind.allCases) { kind in
                        Text(kind.title).tag(kind.rawValue)
                    }
                }
                Picker("Category", selection: $transaction.category) {
                    ForEach(categoryOptions, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
            }

            transferSection

            Section("Source") {
                LabeledContent("Import file", value: transaction.sourceFile)
                if let externalID = transaction.externalID {
                    LabeledContent("Source ID", value: externalID)
                }
            }
        }
        .navigationTitle("Edit booking")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? context.save()
        }
    }

    // Transfers
    @ViewBuilder
    private var transferSection: some View {
        let candidates = possibleCounterBookings

        if transaction.transferGroupID != nil {
            Section("Confirmed transfer") {
                Label("Linked to a counter booking", systemImage: "checkmark.circle.fill")
                Button("Unlink", role: .destructive) {
                    unlinkTransfer()
                }
            }
        } else if !candidates.isEmpty {
            Section {
                ForEach(candidates) { other in
                    Button {
                        linkTransfer(with: other)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Link as internal transfer")
                            Text("\(accountName(other.accountID)) · \(other.bookedAt.bookingLabel) · \(other.amountMinor.euro)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Possible counter bookings")
            } footer: {
                Text("A pair only counts as an internal transfer once you pick it here.")
            }
        }
    }

    private func linkTransfer(with other: TransactionModel) {
        let groupID = UUID()

        for booking in [transaction, other] {
            booking.transferGroupID = groupID
            booking.kindRaw = TransactionKind.transfer.rawValue
            booking.category = "Transfers"
        }
        try? context.save()
    }

    private func unlinkTransfer() {
        guard let groupID = transaction.transferGroupID else { return }

        for booking in allTransactions where booking.transferGroupID == groupID {
            booking.transferGroupID = nil
            booking.kindRaw = booking.amountMinor >= 0 ? TransactionKind.income.rawValue : TransactionKind.expense.rawValue
            booking.category = "Other"
        }
        try? context.save()
    }

    // Helpers
    private func accountName(_ id: UUID) -> String {
        accounts.first { $0.id == id }?.name ?? "Unknown"
    }
}
