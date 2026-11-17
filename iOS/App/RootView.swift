import SwiftUI
import LocalAuthentication

struct RootView: View {
    @AppStorage("requireDeviceAuth") private var requireDeviceAuth = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var authenticationError = ""

    var body: some View {
        Group {
            if !requireDeviceAuth || unlocked {
                tabs
            } else {
                lockScreen
            }
        }
        .onAppear {
            if requireDeviceAuth {
                authenticate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // only lock in the background, the Face ID prompt itself makes the app inactive
            if requireDeviceAuth && phase == .background {
                unlocked = false
            }
        }
        .onChange(of: requireDeviceAuth) { _, enabled in
            unlocked = !enabled
            if enabled {
                authenticate()
            }
        }
    }

    // Tabs
    private var tabs: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Overview", systemImage: "square.grid.2x2") }
            TransactionsView()
                .tabItem { Label("Bookings", systemImage: "list.bullet.rectangle") }
            AccountsView()
                .tabItem { Label("Accounts", systemImage: "creditcard") }
            AnalysisView()
                .tabItem { Label("Analysis", systemImage: "chart.bar.xaxis") }
            SettingsView()
                .tabItem { Label("More", systemImage: "gearshape") }
        }
    }

    // Lock
    private var lockScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 46))
            Text("Accounting")
                .font(.largeTitle.bold())
            Text("Your financial data stays on this device.")
                .foregroundStyle(.secondary)

            if !authenticationError.isEmpty {
                Text(authenticationError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("Unlock with Face ID or passcode", action: authenticate)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func authenticate() {
        let context = LAContext()
        var policyError: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            authenticationError = "Device authentication is not set up."
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Show your financial data") { success, error in
            DispatchQueue.main.async {
                unlocked = success
                authenticationError = success ? "" : (error?.localizedDescription ?? "Authentication failed")
            }
        }
    }
}
