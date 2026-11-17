import SwiftUI
import SwiftData

@main
struct AccountingApp: App {

    // local database, no iCloud
    private let modelContainer: ModelContainer = {
        let schema = Schema([
            AccountModel.self,
            TransactionModel.self,
            ImportBatchModel.self,
            BudgetModel.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not set up the local database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
