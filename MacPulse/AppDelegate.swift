import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private let launchAtLogin = LaunchAtLoginController()
    private lazy var monitor = MonitorStore(settings: settings)
    private var statusController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusController = StatusItemController(
            monitor: monitor,
            settings: settings,
            onOpenSettings: { [weak self] in self?.showSettings() },
            onQuit: { NSApp.terminate(nil) }
        )

        settingsWindowController = SettingsWindowController(
            settings: settings,
            monitor: monitor,
            launchAtLogin: launchAtLogin
        )

        observePowerEvents()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusController?.showPopover(forceVisible: true)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        switch url.host?.lowercased() {
        case "settings": showSettings()
        default: statusController?.showPopover(forceVisible: true)
        }
    }

    private func showSettings() {
        launchAtLogin.refresh()
        settingsWindowController?.present()
    }

    private func observePowerEvents() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.monitor.pauseForSleep() }
            }
        )
        workspaceObservers.append(
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.monitor.resumeAfterWake() }
            }
        )
    }
}
