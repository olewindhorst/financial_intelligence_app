import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AccountingCore

struct AccountsView: View {
    @Query(sort: \AccountModel.createdAt) private var accounts: [AccountModel]
    @Query private var transactions: [TransactionModel]
    @State private var isAdding = false
    @State private var importAccount: AccountModel?

    var body: some View {
        NavigationStack {
            List {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "No accounts yet",
                        systemImage: "creditcard",
                        description: Text("Add a bank or broker account first.")
                    )
                }

                ForEach(accounts) { account in
                    Section {
                        accountRow(account)
                        Button {
                            importAccount = account
                        } label: {
                            Label("Import CSV file", systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add account")
                }
            }
            .sheet(isPresented: $isAdding) {
                AddAccountView()
            }
            .sheet(item: $importAccount) { account in
                ImportAccountView(account: account)
            }
        }
    }

    private func accountRow(_ account: AccountModel) -> some View {
        let bookingCount = transactions.filter { $0.accountID == account.id }.count
        let symbol = account.institution == .broker ? "chart.xyaxis.line" : "building.columns"

        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.headline)
                Text("\(account.institution.rawValue) · \(account.accountType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(bookingCount) bookings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// New account
struct AddAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var institution: Institution = .bank
    @State private var isDepot = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name, e.g. Checking", text: $name)
                Picker("Type", selection: $institution) {
                    ForEach(Institution.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                Toggle("Portfolio", isOn: $isDepot)

                Section {
                    Text("Data is only stored on this iPhone. The app never connects to your bank.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let account = AccountModel(
            name: trimmedName,
            institution: institution,
            accountType: isDepot ? "Portfolio" : "Account"
        )
        context.insert(account)
        try? context.save()
        dismiss()
    }
}

// CSV import
struct ImportAccountView: View {
    let account: AccountModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showingPicker = false
    @State private var showingResult = false
    @State private var reportTitle = "Import"
    @State private var reportMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Target account") {
                    LabeledContent("Account", value: account.name)
                    LabeledContent("Type", value: account.institution.rawValue)
                }

                Section {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Choose CSV from Files", systemImage: "doc.text")
                    }
                } footer: {
                    Text("Recognised fields: booking date, amount, merchant and purpose. Unsupported rows are logged. Only EUR is imported.")
                }
            }
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text]
            ) { response in
                handle(response)
            }
            .alert(reportTitle, isPresented: $showingResult) {
                Button("OK") {}
            } message: {
                Text(reportMessage)
            }
        }
    }

    private func handle(_ response: Result<URL, Error>) {
        switch response {
        case .success(let url):
            do {
                let report = try ImportService.importFile(at: url, for: account, context: context)
                reportTitle = "Import finished"
                reportMessage = report.message
            } catch {
                reportTitle = "Import failed"
                reportMessage = error.localizedDescription
            }
        case .failure(let error):
            reportTitle = "File could not be opened"
            reportMessage = error.localizedDescription
        }
        showingResult = true
    }
}
