import Foundation
import Network

class ServerManager: ObservableObject {
    @Published var isReady = false
    @Published var port: Int = 3000
    @Published var errorMessage: String?

    private var process: Process?
    private var pollTimer: Timer?

    func start(vaultPath: String) {
        let binaryURL = Bundle.main.resourceURL!
            .appendingPathComponent("BrainServer/BrainServer")
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            errorMessage = "BrainServer binary not found in app bundle."
            return
        }

        let selectedPort = availablePort(starting: 3000)
        self.port = selectedPort

        let proc = Process()
        proc.executableURL = binaryURL
        proc.arguments = ["--vault", vaultPath, "--port", String(selectedPort)]
        proc.environment = buildEnvironment()

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.isReady = false }
        }

        do {
            try proc.run()
            self.process = proc
            pollUntilReady(port: selectedPort)
        } catch {
            errorMessage = "Failed to start server: \(error.localizedDescription)"
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        process?.terminate()
        process = nil
        isReady = false
    }

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if let key = KeychainHelper.load(key: "anthropic_api_key") {
            env["ANTHROPIC_API_KEY"] = key
        }
        if let key = KeychainHelper.load(key: "openai_api_key") {
            env["OPENAI_API_KEY"] = key
        }
        // Ensure PATH includes common node/homebrew locations
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin"
        if let existing = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(existing)"
        } else {
            env["PATH"] = extraPaths
        }
        return env
    }

    private func pollUntilReady(port: Int) {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
            req.timeoutInterval = 0.4
            URLSession.shared.dataTask(with: req) { _, response, _ in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
                DispatchQueue.main.async {
                    self.isReady = true
                    timer.invalidate()
                }
            }.resume()
        }
    }

    private func availablePort(starting: Int) -> Int {
        for p in starting...(starting + 20) {
            if portIsAvailable(p) { return p }
        }
        return starting
    }

    private func portIsAvailable(_ port: Int) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    deinit { stop() }
}
