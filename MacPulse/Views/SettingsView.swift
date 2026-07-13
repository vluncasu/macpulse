import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var monitor: MonitorStore
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @State private var copiedDiagnostics = false

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "switch.2") }

            appearanceTab
                .tabItem { Label("Appearance", systemImage: "circle.lefthalf.filled") }

            samplingTab
                .tabItem { Label("Sampling", systemImage: "waveform.path.ecg") }

            widgetsTab
                .tabItem { Label("Widgets", systemImage: "rectangle.3.group") }

            compatibilityTab
                .tabItem { Label("Compatibility", systemImage: "desktopcomputer") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
        .frame(minWidth: 690, minHeight: 550)
        .onAppear { launchAtLogin.refresh() }
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle(
                    "Start \(settings.resolvedAppDisplayName) at login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                Text("\(settings.resolvedAppDisplayName) launches silently as an accessory application: no Dock icon, window, notification, or focus change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Login item status", value: launchAtLogin.statusDescription)

                if launchAtLogin.requiresApproval {
                    Label(
                        "Approve \(settings.resolvedAppDisplayName) in System Settings → General → Login Items.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                if let error = launchAtLogin.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Menu bar") {
                Toggle("Show menu bar item", isOn: $settings.showMenuBarItem)
                Picker("Display", selection: $settings.menuBarDisplay) {
                    ForEach(MenuBarDisplay.allCases) { display in
                        Text(display.title).tag(display)
                    }
                }
                Text("Icon only is the quiet default. Numeric labels are intentionally rate-limited to avoid constant visual movement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Displayed names") {
                TextField("App display name", text: $settings.appDisplayName)
                TextField("CPU label", text: $settings.cpuDisplayName)
                TextField("GPU label", text: $settings.gpuDisplayName)
                Text("These names affect the visible interface labels. They do not change the bundle identifier or the installed application name on disk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Monitoring") {
                HStack {
                    Text("Engine")
                    Spacer()
                    Text(monitor.samplingState.rawValue).foregroundStyle(.secondary)
                    Button(monitor.isRunning ? "Pause" : "Resume") {
                        monitor.toggleRunning()
                    }
                }
                Button("Refresh telemetry now") { monitor.forceRefresh() }
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section("Motion") {
                Picker("Visual response", selection: $settings.visualResponse) {
                    ForEach(VisualResponse.allCases) { response in
                        Text(response.title).tag(response)
                    }
                }
                Text(settings.visualResponse.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The Calm profile uses fast attack and slow release: short peaks remain visible, while falling values settle gradually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dashboard") {
                Toggle("Show memory information", isOn: $settings.showMemory)
                Toggle("Show advanced GPU telemetry", isOn: $settings.showAdvancedDetails)
                Picker("Live history", selection: $settings.historyWindow) {
                    ForEach(HistoryWindow.allCases) { window in
                        Text(window.title).tag(window)
                    }
                }
            }

            Section {
                Button("Restore visual defaults") {
                    settings.visualResponse = .calm
                    settings.menuBarDisplay = .iconOnly
                    settings.showMemory = true
                    settings.showAdvancedDetails = true
                    settings.historyWindow = .threeMinutes
                    settings.appDisplayName = AppConstants.appName
                    settings.cpuDisplayName = "CPU"
                    settings.gpuDisplayName = "GPU"
                }
            }
        }
        .formStyle(.grouped)
    }

    private var samplingTab: some View {
        Form {
            Section("Adaptive sampling") {
                Picker("Profile", selection: $settings.samplingProfile) {
                    ForEach(SamplingProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                Text(settings.samplingProfile.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Respect Low Power Mode", isOn: $settings.respectLowPowerMode)
                Text("Sampling accelerates while the dashboard is visible and progressively backs off during sustained idle periods. Serious thermal states override the selected profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Graphics selection") {
                Picker("Primary GPU", selection: $settings.gpuSelectionMode) {
                    ForEach(GPUSelectionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text("Automatic preserves the most useful active device when possible, then considers telemetry quality, utilization, and discrete/integrated hints.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if monitor.snapshot.availableGPUs.isEmpty {
                    Text("No GPU telemetry service has produced a usable sample yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monitor.snapshot.availableGPUs) { gpu in
                        LabeledContent(gpu.modelName, value: gpu.usage.map { "\(Int($0.rounded()))%" } ?? "Unavailable")
                    }
                }
            }

            Section("Current policy") {
                LabeledContent("State", value: monitor.samplingState.rawValue)
                LabeledContent(
                    "Effective interval",
                    value: String(format: "%.2f seconds", monitor.snapshot.effectiveSamplingInterval)
                )
                LabeledContent(
                    "Low Power Mode",
                    value: monitor.snapshot.lowPowerModeEnabled ? "Enabled" : "Disabled"
                )
                LabeledContent("Thermal state", value: thermalStateText)
            }
        }
        .formStyle(.grouped)
    }

    private var widgetsTab: some View {
        Form {
            Section("Widget synchronization") {
                Toggle("Keep widgets synchronized", isOn: $settings.widgetSyncEnabled)
                LabeledContent(
                    "Shared storage",
                    value: monitor.lastPersistenceSucceeded ? "Available" : "Unavailable"
                )
                Text("The menu-bar process samples continuously. The widget performs an independent, bounded sample whenever WidgetKit requests a timeline; the live menu-bar dashboard remains the real-time surface.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Included widgets") {
                widgetDescription("Overview", "Small, medium, and large layouts with CPU, GPU, memory, state, and history.")
                widgetDescription("CPU", "A focused CPU gauge for small and medium layouts.")
                widgetDescription("GPU", "A focused GPU gauge with telemetry availability and device name.")
            }

            Section("Add to desktop") {
                Text("Control-click the desktop → Edit Widgets → search for “MacPulse” → choose a layout.")
                    .font(.caption)
                Button("Refresh widget snapshot") { monitor.forceRefresh() }
            }
        }
        .formStyle(.grouped)
    }

    private var compatibilityTab: some View {
        Form {
            Section("Detected system") {
                LabeledContent("Hardware model", value: monitor.snapshot.machine.hardwareModel)
                LabeledContent("Processor", value: monitor.snapshot.machine.processorName)
                LabeledContent("Architecture", value: monitor.snapshot.machine.architecture)
                LabeledContent("Platform class", value: monitor.snapshot.machine.compatibilityClass)
                LabeledContent("macOS", value: monitor.snapshot.machine.operatingSystemVersion)
            }

            Section("GPU providers") {
                if monitor.snapshot.availableGPUs.isEmpty {
                    Text("GPU activity is not currently exposed by AGXAccelerator or IOAccelerator. CPU monitoring remains fully functional.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monitor.snapshot.availableGPUs) { gpu in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gpu.modelName).font(.headline)
                            Text("\(gpu.source.rawValue) · \(gpu.registryClass)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Activity: \(gpu.usage.map { "\(Int($0.rounded()))%" } ?? "not exposed") · additional fields: \(gpu.detailCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
                Text("Hackintosh support depends on native graphics acceleration and the properties published by the active macOS driver. \(settings.resolvedAppDisplayName) does not install or modify kernel extensions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Power telemetry") {
                LabeledContent("Source", value: monitor.snapshot.power.sourceDescription)
                LabeledContent("Total system", value: formattedPower(monitor.snapshot.power.totalSystemWatts))
                LabeledContent("GPU", value: formattedPower(monitor.snapshot.power.gpuWatts))
                LabeledContent("CPU package", value: formattedPower(monitor.snapshot.power.cpuPackageWatts))
                LabeledContent("Memory", value: formattedPower(monitor.snapshot.power.memoryWatts))
                if let sum = monitor.snapshot.power.knownComponentSumWatts {
                    LabeledContent("Known component sum", value: formattedPower(sum))
                }
                Text("Total system power is only shown when macOS exposes it. On many Intel Macs, Apple Silicon Macs, and Hackintosh systems, macOS does not provide complete unprivileged package-level CPU/RAM/GPU power telemetry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                HStack {
                    Button(copiedDiagnostics ? "Copied" : "Copy diagnostic report") {
                        copyDiagnostics()
                    }
                    Button("Export JSON…") { exportDiagnostics() }
                }
                Text("The report excludes the user name, host name, file paths, serial number, and network identifiers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .font(.system(size: 44, weight: .semibold))
                        .frame(width: 66, height: 66)
                        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.resolvedAppDisplayName).font(.title2.weight(.semibold))
                        Text(versionText).foregroundStyle(.secondary)
                        Text("Quiet native telemetry for macOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Principles") {
                Label("No analytics or network requests", systemImage: "lock.shield")
                Label("No fan, clock, voltage, or driver control", systemImage: "hand.raised")
                Label("Unsupported metrics are never fabricated", systemImage: "checkmark.seal")
                Label("Native Swift, SwiftUI, AppKit, WidgetKit, Mach, and IOKit", systemImage: "swift")
            }

            Section("Developed by") {
                Button("Open TerabitLab website") {
                    NSWorkspace.shared.open(AppConstants.developerURL)
                }
                Text("Developed by \(AppConstants.developerName) · \(AppConstants.developerURL.absoluteString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Project") {
                Button("Open GitHub repository") {
                    NSWorkspace.shared.open(AppConstants.repositoryURL)
                }
                Button("Restore all defaults") { settings.restoreDefaults() }
                Text("MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func widgetDescription(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    private var thermalStateText: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private func formattedPower(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded())) W" } ?? "Not exposed"
    }

    private func copyDiagnostics() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(monitor.diagnosticsJSON(), forType: .string)
        copiedDiagnostics = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedDiagnostics = false
        }
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.title = "Export MacPulse Diagnostics"
        panel.nameFieldStringValue = "MacPulse-Diagnostics.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? monitor.diagnosticsJSON().write(to: url, atomically: true, encoding: .utf8)
    }
}
