import Foundation
import AuthenticationServices
import Supabase

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published var user: AuthUser?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: SupabaseClient

    override init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    storage: UserDefaultsAuthStorage()
                )
            )
        )
        super.init()
        Task { await loadStoredSession() }
    }

    var isSignedIn: Bool { user != nil }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: SupabaseConfig.oauthRedirectURL,
                launchFlow: { url in
                    try await self.startWebAuthSession(url: url)
                }
            )
            let authUser = AuthUser(from: session.user)
            self.user = authUser
            Task { await recordSignIn(authUser) }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func handleCallback(url: URL) async {
        do {
            try await client.auth.session(from: url)
            if let user = try? await client.auth.user() {
                let authUser = AuthUser(from: user)
                self.user = authUser
                Task { await recordSignIn(authUser) }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func recordSignIn(_ user: AuthUser) async {
        struct SignInRow: Encodable {
            let user_id: String
            let email: String
            let app_version: String
            let device_name: String
        }
        let row = SignInRow(
            user_id: user.id.uuidString,
            email: user.email,
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            device_name: Host.current().localizedName ?? "Mac"
        )
        do {
            try await client.from("install_signins").insert(row).execute()
        } catch {
            // Non-blocking analytics — log but don't surface to the user
            print("Failed to record sign-in event: \(error)")
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
            self.user = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadStoredSession() async {
        if let user = try? await client.auth.user() {
            self.user = AuthUser(from: user)
        }
    }

    private func startWebAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "brainsquared"
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthError.noCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    enum AuthError: LocalizedError {
        case noCallback
        var errorDescription: String? {
            switch self {
            case .noCallback: return "Sign-in was cancelled."
            }
        }
    }
}

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}

struct AuthUser: Equatable {
    let id: UUID
    let email: String

    init(from user: User) {
        self.id = user.id
        self.email = user.email ?? ""
    }
}

/// Stores Supabase session data in UserDefaults instead of Keychain.
/// Avoids the keychain ACL prompt that fires on every dev rebuild because
/// ad-hoc code signatures change. For production with a stable signing identity,
/// switch back to KeychainLocalStorage.
final class UserDefaultsAuthStorage: AuthLocalStorage {
    private let prefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: prefix + key)
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: prefix + key)
    }
}
