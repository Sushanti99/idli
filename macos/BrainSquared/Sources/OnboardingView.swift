import SwiftUI

struct OnboardingView: View {
    let onComplete: (String) -> Void

    @EnvironmentObject var authManager: AuthManager
    @State private var step = 0
    @State private var vaultPath = ""
    @State private var anthropicKey = ""
    @State private var openaiKey = ""
    @State private var installState: InstallState = .idle

    enum InstallState {
        case idle, running(String), done, failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 440)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrainLogoView(size: 36)
            Text("Set up brain²")
                .font(.title2.bold())
            Spacer()
            StepIndicator(current: step, total: 4)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: signInStep
        case 1: vaultStep
        case 2: apiKeysStep
        case 3: installStep
        default: EmptyView()
        }
    }

    // MARK: Step 0 – Sign in

    private var signInStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sign in to brain²")
                    .font(.headline)
                Text("Sign in with your Google account so your integrations stay connected across devices.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let user = authManager.user {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Signed in as \(user.email)")
                        .foregroundColor(.secondary)
                }
            } else if let error = authManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            HStack {
                Spacer()
                if authManager.user != nil {
                    Button("Continue") { step = 1 }
                        .buttonStyle(.borderedProminent)
                } else if authManager.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await authManager.signInWithGoogle() }
                    } label: {
                        Label("Sign in with Google", systemImage: "g.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .onChange(of: authManager.user) { newUser in
            if newUser != nil { step = 1 }
        }
    }

    // MARK: Step 1 – Vault

    private var vaultStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose where brain² stores your notes")
                    .font(.headline)
                Text("Pick an existing folder or create a new one — brain² will set itself up inside it.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text(vaultPath.isEmpty ? "No folder selected" : vaultPath)
                    .foregroundColor(vaultPath.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                Button("Choose…") { pickVault() }
                Button("New Folder…") { createNewFolder() }
            }

            Spacer()

            HStack {
                Button("Back") { step = 0 }
                Spacer()
                Button("Continue") { step = 2 }
                    .buttonStyle(.borderedProminent)
                    .disabled(vaultPath.isEmpty)
            }
        }
        .padding(32)
    }

    // MARK: Step 2 – API Keys

    private var apiKeysStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add your API keys")
                    .font(.headline)
                Text("Keys are stored securely in your macOS Keychain — never on disk or sent anywhere.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("Anthropic API key (required)", systemImage: "key.fill")
                    .font(.subheadline.bold())
                SecureField("sk-ant-…", text: $anthropicKey)
                    .textFieldStyle(.roundedBorder)
                Text("Used by brain² and the claude-code CLI.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Label("OpenAI API key (optional — for Codex)", systemImage: "key")
                    .font(.subheadline.bold())
                SecureField("sk-…", text: $openaiKey)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            HStack {
                Button("Back") { step = 1 }
                Spacer()
                Button("Continue") { step = 3 }
                    .buttonStyle(.borderedProminent)
                    .disabled(anthropicKey.isEmpty)
            }
        }
        .padding(32)
    }

    // MARK: Step 3 – CLI Install

    private var installStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Installing CLIs")
                    .font(.headline)
                Text("brain² installs claude-code and codex so you can run AI agents directly from your vault.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            installStatusView

            Spacer()

            HStack {
                Button("Back") { step = 2; installState = .idle }
                    .disabled({ if case .running = installState { return true }; return false }())
                Spacer()
                if case .done = installState {
                    Button("Launch brain²") { finishOnboarding() }
                        .buttonStyle(.borderedProminent)
                } else if case .failed = installState {
                    Button("Skip & Launch") { finishOnboarding() }
                        .buttonStyle(.bordered)
                } else {
                    Button("Install") { runInstall() }
                        .buttonStyle(.borderedProminent)
                        .disabled({ if case .running = installState { return true }; return false }())
                }
            }
        }
        .padding(32)
        .onAppear { if case .idle = installState { runInstall() } }
    }

    @ViewBuilder
    private var installStatusView: some View {
        switch installState {
        case .idle:
            ProgressView("Preparing…")
        case .running(let msg):
            HStack(spacing: 12) {
                ProgressView()
                Text(msg).foregroundColor(.secondary)
            }
        case .done:
            Label("CLIs installed successfully", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Label("CLI install failed", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("You can still use brain² — install manually later with:\nnpm install -g @anthropic-ai/claude-code @openai/codex")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: Actions

    private func pickVault() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Pick an existing folder or use New Folder to create one."
        if panel.runModal() == .OK, let url = panel.url {
            vaultPath = url.path
        }
    }

    private func createNewFolder() {
        let panel = NSSavePanel()
        panel.prompt = "Create"
        panel.message = "Name your brain² folder"
        panel.nameFieldStringValue = "My Brain"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                vaultPath = url.path
            } catch {
                // Fall back to pick panel if creation fails
                pickVault()
            }
        }
    }

    private func runInstall() {
        installState = .running("Installing CLIs…")
        CLIInstaller.installAll(
            anthropicKey: anthropicKey,
            openaiKey: openaiKey.isEmpty ? nil : openaiKey,
            progress: { msg in
                DispatchQueue.main.async { installState = .running(msg) }
            },
            completion: { error in
                DispatchQueue.main.async {
                    if let error {
                        installState = .failed(error.localizedDescription)
                    } else {
                        installState = .done
                    }
                }
            }
        )
    }

    private func finishOnboarding() {
        KeychainHelper.save(key: "anthropic_api_key", value: anthropicKey)
        if !openaiKey.isEmpty {
            KeychainHelper.save(key: "openai_api_key", value: openaiKey)
        }
        initVault()
        onComplete(vaultPath)
    }

    private func initVault() {
        guard let execURL = Bundle.main.executableURL,
              FileManager.default.fileExists(atPath: execURL.deletingLastPathComponent().appendingPathComponent("BrainServer").path)
        else { return }
        BrainConfigWriter.writeDefaultConfig(vaultPath: vaultPath, anthropicKey: anthropicKey)
    }
}

struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i <= current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}
