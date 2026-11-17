import SwiftUI
import SwiftData
import AccountingCore

struct AnalysisView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [TransactionModel]
    @Query(sort: \BudgetModel.category) private var budgets: [BudgetModel]
    @State private var selectedMonth = Date()
    @State private var isAddingBudget = false

    private var monthRecords: [TransactionRecord] {
        let interval = FinanceAnalytics.monthInterval(containing: selectedMonth)
        return transactions.map(\.record).filter { interval.contains($0.bookedAt) }
    }

    private var categories: [(category: String, amountMinor: Int64)] {
        FinanceAnalytics.expensesByCategory(monthRecords)
    }

    var body: some View {
        // calculate once per render, the budget rows need it too
        let spending = categories

        NavigationStack {
            List {
                Section {
                    DatePicker("Month", selection: $selectedMonth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                } footer: {
                    Text("Expenses leave out security purchases and confirmed transfers between your own accounts.")
                }

                Section("Expenses by category") {
                    if spending.isEmpty {
                        Text("No expenses this month")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(spending, id: \.category) { item in
                        HStack {
                            Text(item.category)
                            Spacer()
                            Text(item.amountMinor.euro)
                                .fontWeight(.medium)
                        }
                    }
                }

                Section("Monthly budgets") {
                    if budgets.isEmpty {
                        Text("Set a monthly budget per category.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(budgets) { budget in
                        let spent = spending.first { $0.category == budget.category }?.amountMinor ?? 0
                        BudgetRow(budget: budget, spent: spent)
                    }
                    .onDelete(perform: deleteBudgets)

                    Button {
                        isAddingBudget = true
                    } label: {
                        Label("Add or change budget", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Analysis")
            .sheet(isPresented: $isAddingBudget) {
                BudgetEditorView()
            }
        }
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            context.delete(budgets[index])
        }
        try? context.save()
    }
}

// Budget row
struct BudgetRow: View {
    let budget: BudgetModel
    let spent: Int64

    private var limit: Int64 {
        budget.monthlyLimitMinor
    }

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(1, Double(spent) / Double(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(budget.category)
                    .fontWeight(.medium)
                Spacer()
                Text("\(spent.euro) / \(limit.euro)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(spent > limit ? Color.red : Color.blue)

            if spent > limit {
                Text("Over budget by \((spent - limit).euro)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// Budget editor
struct BudgetEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [BudgetModel]
    @State private var category = "Groceries"
    @State private var amount = "250.00"
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(CategoryRules.defaults, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                TextField("Monthly limit (EUR)", text: $amount)
                    .keyboardType(.decimalPad)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("If the category already has a budget, it gets updated.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Monthly budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        guard let limit = MoneyParser.minorUnits(amount), limit > 0 else {
            errorMessage = "Please enter a positive EUR amount."
            return
        }

        if let existing = budgets.first(where: { $0.category == category }) {
            existing.monthlyLimitMinor = limit
        } else {
            context.insert(BudgetModel(category: category, monthlyLimitMinor: limit))
        }

        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
