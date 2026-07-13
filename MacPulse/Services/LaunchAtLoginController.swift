import Combine
import Darwin
import Foundation
import ServiceManagement

/// Controls login startup without requiring an Apple Developer Team.
///
/// `SMAppService` remains the preferred native path. Locally ad-hoc signed
/// builds can occasionally be rejected by Service Management, so MacPulse has
/// a user-scoped LaunchAgent fallback. The fallback only calls `/usr/bin/open`
/// for this app bundle, runs without elevated privileges, and is removable by
/// the same toggle.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var nativeStatus: SMAppService.Status = SMAppService.mainApp.status
    @Published private(set) var fallbackEnabled = false
    @Published private(set) var lastError: String?

    var isEnabled: Bool {
        nativeStatus == .enabled || fallbackEnabled
    }

    var requiresApproval: Bool {
        nativeStatus == .requiresApproval && !fallbackEnabled
    }

    var statusDescription: String {
        if nativeStatus == .enabled { return "Enabled · macOS login item" }
        if fallbackEnabled { return "Enabled · local compatibility mode" }
        if nativeStatus == .requiresApproval { return "Waiting for macOS approval" }
        return "Disabled"
    }

    func refresh() {
        nativeStatus = SMAppService.mainApp.status
        fallbackEnabled = FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil

        if enabled {
            enable()
        } else {
            disable()
        }
        refresh()
    }

    private func enable() {
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            nativeStatus = SMAppService.mainApp.status
            if nativeStatus == .enabled || nativeStatus == .requiresApproval {
                try? removeFallback()
                return
            }
        } catch {
            // Continue to the local, user-scoped fallback below.
        }

        do {
            try installFallback()
            fallbackEnabled = true
        } catch {
            lastError = "Could not enable startup: \(error.localizedDescription)"
        }
    }

    private func disable() {
        var errors: [String] = []

        do {
            if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errors.append(error.localizedDescription)
        }

        do {
            try removeFallback()
        } catch {
            errors.append(error.localizedDescription)
        }

        if !errors.isEmpty {
            lastError = errors.joined(separator: " · ")
        }
    }

    private var launchAgentLabel: String {
        "\(Bundle.main.bundleIdentifier ?? "com.macpulse.local.MacPulse").login"
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(launchAgentLabel).plist", isDirectory: false)
    }

    private func installFallback() throws {
        let directory = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let propertyList: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [
                "/usr/bin/open",
                "-gj",
                Bundle.main.bundleURL.path
            ],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
            "StandardOutPath": "/dev/null",
            "StandardErrorPath": "/dev/null"
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: [.atomic])

        // Bootstrap is best-effort. The file itself is sufficient for the next
        // login, while bootstrapping makes the new state visible immediately.
        _ = runLaunchctl(["bootout", launchDomain, launchAgentURL.path])
        let result = runLaunchctl(["bootstrap", launchDomain, launchAgentURL.path])
        if result != 0 {
            // launchd may already know the job. Do not fail when the durable
            // plist has been written correctly.
            guard FileManager.default.fileExists(atPath: launchAgentURL.path) else {
                throw LaunchAtLoginError.launchctlFailed(result)
            }
        }
    }

    private func removeFallback() throws {
        _ = runLaunchctl(["bootout", launchDomain, launchAgentURL.path])
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
        }
        fallbackEnabled = false
    }

    private var launchDomain: String {
        "gui/\(getuid())"
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case launchctlFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .launchctlFailed(let status):
            return "launchctl returned status \(status)"
        }
    }
}
