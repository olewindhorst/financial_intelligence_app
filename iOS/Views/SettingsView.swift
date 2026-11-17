import SwiftUI
import SwiftData
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("requireDeviceAuth") private var requireDeviceAuth = false
    @Environment(\.modelContext) private var context
    @Query(sort: \ImportBatchModel.date, order: .reverse) private var imports: [ImportBatchModel]
    @Query private var transactions: [TransactionModel]
    @Query private var accounts: [AccountModel]
    @State private var exportURL: URL?
    @State private var showAddDemoConfirmation = false
    @State private var showRemoveDemoConfirmation = false
    @State private var message = ""
    @State private var showMessage = false

    var body: some View {
        NavigationStack {
            List {
                privacySection
                exportSection
                demoSection
                historySection

                Section("About") {
                    Text("Local app · EUR · CSV import · No bank API · No portfolio market values.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("More")
            .confirmationDialog("Add demo data?", isPresented: $showAddDemoConfirmation) {
                Button("Add") {
                    run { try DemoData.seed(context: context) }
                }
            } message: {
                Text("Only synthetic bookings are created.")
            }
            .confirmationDialog("Remove all demo accounts and their bookings?", isPresented: $showRemoveDemoConfirmation) {
                Button("Delete demo data", role: .destructive) {
                    run { try DemoData.deleteDemo(context: context) }
                }
            } message: {
                Text("Real accounts and their bookings are kept.")
            }
            .alert("Note", isPresented: $showMessage) {
                Button("OK") {}
            } message: {
                Text(message)
            }
        }
    }

    // Privacy
    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Device lock", isOn: Binding(get: { requireDeviceAuth }, set: setDeviceAuth))
            Text("The app needs no bank login and never syncs to the cloud. The lock does not keep the data out of iPhone backups.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func setDeviceAuth(_ requested: Bool) {
        guard requested else {
            requireDeviceAuth = false
            return
        }

        var policyError: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) {
            requireDeviceAuth = true
        } else {
            message = "Please set up Face ID or a passcode in the iPhone settings first."
            showMessage = true
        }
    }

    // Export
    private var exportSection: some View {
        Section("Export") {
            Button {
                createExport()
            } label: {
                Label("Create CSV export", systemImage: "square.and.arrow.up")
            }

            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Save or share export", systemImage: "square.and.arrow.up.on.square")
                }
            }

            Text("The export contains personal financial data. Only share it with places you trust.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func createExport() {
        // remove the old file first, no need to keep several copies around
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }

        do {
            exportURL = try ExportService.create(transactions: transactions, accounts: accounts)
        } catch {
            message = error.localizedDescription
            showMessage = true
        }
    }

    // Demo
    private var demoSection: some View {
        Section("Demo data") {
            Button("Add synthetic demo data") {
                showAddDemoConfirmation = true
            }
            Button("Remove demo data", role: .destructive) {
                showRemoveDemoConfirmation = true
            }
            Text("All demo accounts are marked with DEMO. No real financial data is created.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // History
    private var historySection: some View {
        Section("Import history") {
            if imports.isEmpty {
                Text("No CSV imports yet")
                    .foregroundStyle(.secondary)
            }

            ForEach(imports) { batch in
                VStack(alignment: .leading, spacing: 5) {
                    Text(batch.filename)
                        .font(.subheadline.weight(.semibold))
                    Text("\(batch.date.bookingLabel) · \(batch.inserted) new · \(batch.duplicates) duplicates · \(batch.rejected) rejected")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !batch.issues.isEmpty {
                        DisclosureGroup("Notes") {
                            Text(batch.issues)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            message = "Done."
        } catch {
            message = error.localizedDescription
        }
        showMessage = true
    }
}
