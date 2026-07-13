import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let monitor: MonitorStore
    private let settings: SettingsStore
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var forcedVisible = false
    private var lastTitleUpdate = Date.distantPast
    private var lastRenderedTitle = ""

    init(
        monitor: MonitorStore,
        settings: SettingsStore,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 452, height: 690)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: DashboardView(
                monitor: monitor,
                settings: settings,
                onOpenSettings: onOpenSettings,
                onQuit: onQuit
            )
        )

        settings.$showMenuBarItem
            .removeDuplicates()
            .sink { [weak self] _ in self?.reconcileStatusItem() }
            .store(in: &cancellables)

        settings.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updatePresentation(
                        snapshot: self.monitor.snapshot,
                        display: self.settings.menuBarDisplay,
                        isRunning: self.monitor.isRunning
                    )
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            monitor.$snapshot,
            settings.$menuBarDisplay,
            monitor.$isRunning
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] snapshot, display, isRunning in
            self?.updatePresentation(snapshot: snapshot, display: display, isRunning: isRunning)
        }
        .store(in: &cancellables)

        reconcileStatusItem()
    }

    func showPopover(forceVisible: Bool = false) {
        if forceVisible, statusItem == nil {
            forcedVisible = true
            installStatusItem()
        }
        guard let button = statusItem?.button else {
            onOpenSettings()
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            monitor.setDashboardVisible(true)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        monitor.setDashboardVisible(false)
        if forcedVisible, !settings.showMenuBarItem {
            removeStatusItem()
        }
    }

    private func reconcileStatusItem() {
        if settings.showMenuBarItem || forcedVisible {
            if statusItem == nil { installStatusItem() }
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
        button.toolTip = "\(settings.resolvedAppDisplayName) — CPU and GPU activity"
        updatePresentation(
            snapshot: monitor.snapshot,
            display: settings.menuBarDisplay,
            isRunning: monitor.isRunning
        )
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        if popover.isShown { popover.performClose(nil) }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        forcedVisible = false
        monitor.setDashboardVisible(false)
    }

    private func updatePresentation(
        snapshot: SystemSnapshot,
        display: MenuBarDisplay,
        isRunning: Bool
    ) {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: isRunning
                ? "gauge.with.dots.needle.50percent"
                : "pause.circle",
            accessibilityDescription: settings.resolvedAppDisplayName
        )
        button.toolTip = "\(settings.resolvedAppDisplayName) — \(settings.resolvedCPUDisplayName) and \(settings.resolvedGPUDisplayName) activity"

        let title: String
        switch display {
        case .iconOnly:
            title = ""
        case .cpu:
            title = "  \(settings.resolvedCPUDisplayName.prefix(1).uppercased()) \(Int(snapshot.cpu.usage.rounded()))%"
        case .cpuAndGPU:
            let gpuText = snapshot.gpu.usage.map { "\(Int($0.rounded()))%" } ?? "—"
            title = "  \(settings.resolvedCPUDisplayName.prefix(1).uppercased()) \(Int(snapshot.cpu.usage.rounded()))%  \(settings.resolvedGPUDisplayName.prefix(1).uppercased()) \(gpuText)"
        }

        let now = Date()
        let mayUpdate = display == .iconOnly
            || lastRenderedTitle.isEmpty
            || now.timeIntervalSince(lastTitleUpdate) >= 1.5
        guard mayUpdate, title != lastRenderedTitle else { return }
        lastRenderedTitle = title
        lastTitleUpdate = now
        button.title = title
        button.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: .medium
        )
        button.setAccessibilityLabel(accessibilityText(snapshot: snapshot, isRunning: isRunning))
    }

    private func accessibilityText(snapshot: SystemSnapshot, isRunning: Bool) -> String {
        let gpu = snapshot.gpu.usage.map { "\(settings.resolvedGPUDisplayName) \(Int($0.rounded())) percent" } ?? "\(settings.resolvedGPUDisplayName) unavailable"
        return "\(settings.resolvedAppDisplayName), \(isRunning ? "monitoring" : "paused"), \(settings.resolvedCPUDisplayName) \(Int(snapshot.cpu.usage.rounded())) percent, \(gpu)"
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            showPopover()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open \(settings.resolvedAppDisplayName)", action: #selector(openFromMenu), keyEquivalent: "")
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshFromMenu), keyEquivalent: "r")
        let pause = NSMenuItem(
            title: monitor.isRunning ? "Pause Monitoring" : "Resume Monitoring",
            action: #selector(toggleMonitoringFromMenu),
            keyEquivalent: ""
        )
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(settingsFromMenu), keyEquivalent: ",")
        let quit = NSMenuItem(title: "Quit \(settings.resolvedAppDisplayName)", action: #selector(quitFromMenu), keyEquivalent: "q")
        [open, refresh, pause, settingsItem, quit].forEach { $0.target = self }
        menu.addItem(open)
        menu.addItem(refresh)
        menu.addItem(pause)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openFromMenu() { showPopover() }
    @objc private func refreshFromMenu() { monitor.forceRefresh() }
    @objc private func toggleMonitoringFromMenu() { monitor.toggleRunning() }
    @objc private func settingsFromMenu() { onOpenSettings() }
    @objc private func quitFromMenu() { onQuit() }
}
