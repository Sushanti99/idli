import SwiftUI

@main
struct BrainSquaredApp: App {
    @StateObject private var serverManager = ServerManager()
    @StateObject private var authManager = AuthManager()
    @AppStorage("vaultPath") private var vaultPath: String = ""
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding && !vaultPath.isEmpty && authManager.isSignedIn {
                    ContentView()
                        .environmentObject(serverManager)
                        .onAppear {
                            serverManager.start(vaultPath: vaultPath, userId: authManager.user?.id.uuidString)
                        }
                } else {
                    OnboardingView { completedVaultPath in
                        vaultPath = completedVaultPath
                        hasCompletedOnboarding = true
                        serverManager.start(vaultPath: completedVaultPath, userId: authManager.user?.id.uuidString)
                    }
                    .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                Task { await authManager.handleCallback(url: url) }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Divider()
                if let email = authManager.user?.email, !email.isEmpty {
                    Button("Signed in as \(email)") {}
                        .disabled(true)
                    Button("Sign Out") {
                        Task {
                            serverManager.stop()
                            await authManager.signOut()
                        }
                    }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
                }
            }
        }
    }
}
