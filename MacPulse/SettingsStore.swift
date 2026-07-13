import Combine
import Foundation

enum VisualResponse: String, CaseIterable, Identifiable {
    case calm
    case balanced
    case direct

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calm: return "Calm"
        case .balanced: return "Balanced"
        case .direct: return "Direct"
        }
    }

    var explanation: String {
        switch self {
        case .calm: return "Gentle transitions that avoid sudden visual changes."
        case .balanced: return "Faster transitions while retaining visual stability."
        case .direct: return "Minimal filtering for diagnostic work."
        }
    }

    var smoothingEnabled: Bool { self != .direct }
    var attackTime: TimeInterval { self == .calm ? 0.75 : 0.45 }
    var releaseTime: TimeInterval { self == .calm ? 1.8 : 1.0 }
}

enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case iconOnly
    case cpu
    case cpuAndGPU

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .cpu: return "CPU percentage"
        case .cpuAndGPU: return "CPU and GPU"
        }
    }
}

enum HistoryWindow: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case threeMinutes = 180
    case tenMinutes = 600

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .threeMinutes: return "3 minutes"
        case .tenMinutes: return "10 minutes"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let samplingProfile = "samplingProfile"
        static let visualResponse = "visualResponse"
        static let menuBarDisplay = "menuBarDisplay"
        static let gpuSelectionMode = "gpuSelectionMode"
        static let historyWindow = "historyWindow"
        static let showMenuBarItem = "showMenuBarItem"
        static let widgetSyncEnabled = "widgetSyncEnabled"
        static let showMemory = "showMemory"
        static let showAdvancedDetails = "showAdvancedDetails"
        static let respectLowPowerMode = "respectLowPowerMode"
        static let appDisplayName = "appDisplayName"
        static let cpuDisplayName = "cpuDisplayName"
        static let gpuDisplayName = "gpuDisplayName"
    }

    private let defaults: UserDefaults

    @Published var samplingProfile: SamplingProfile {
        didSet { defaults.set(samplingProfile.rawValue, forKey: Key.samplingProfile) }
    }
    @Published var visualResponse: VisualResponse {
        didSet { defaults.set(visualResponse.rawValue, forKey: Key.visualResponse) }
    }
    @Published var menuBarDisplay: MenuBarDisplay {
        didSet { defaults.set(menuBarDisplay.rawValue, forKey: Key.menuBarDisplay) }
    }
    @Published var gpuSelectionMode: GPUSelectionMode {
        didSet { defaults.set(gpuSelectionMode.rawValue, forKey: Key.gpuSelectionMode) }
    }
    @Published var historyWindow: HistoryWindow {
        didSet { defaults.set(historyWindow.rawValue, forKey: Key.historyWindow) }
    }
    @Published var showMenuBarItem: Bool {
        didSet { defaults.set(showMenuBarItem, forKey: Key.showMenuBarItem) }
    }
    @Published var widgetSyncEnabled: Bool {
        didSet { defaults.set(widgetSyncEnabled, forKey: Key.widgetSyncEnabled) }
    }
    @Published var showMemory: Bool {
        didSet { defaults.set(showMemory, forKey: Key.showMemory) }
    }
    @Published var showAdvancedDetails: Bool {
        didSet { defaults.set(showAdvancedDetails, forKey: Key.showAdvancedDetails) }
    }
    @Published var respectLowPowerMode: Bool {
        didSet { defaults.set(respectLowPowerMode, forKey: Key.respectLowPowerMode) }
    }
    @Published var appDisplayName: String {
        didSet { defaults.set(appDisplayName, forKey: Key.appDisplayName) }
    }
    @Published var cpuDisplayName: String {
        didSet { defaults.set(cpuDisplayName, forKey: Key.cpuDisplayName) }
    }
    @Published var gpuDisplayName: String {
        didSet { defaults.set(gpuDisplayName, forKey: Key.gpuDisplayName) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        samplingProfile = SamplingProfile(
            rawValue: defaults.string(forKey: Key.samplingProfile) ?? ""
        ) ?? .balanced
        visualResponse = VisualResponse(
            rawValue: defaults.string(forKey: Key.visualResponse) ?? ""
        ) ?? .calm
        menuBarDisplay = MenuBarDisplay(
            rawValue: defaults.string(forKey: Key.menuBarDisplay) ?? ""
        ) ?? .iconOnly
        gpuSelectionMode = GPUSelectionMode(
            rawValue: defaults.string(forKey: Key.gpuSelectionMode) ?? ""
        ) ?? .automatic
        historyWindow = HistoryWindow(
            rawValue: defaults.integer(forKey: Key.historyWindow)
        ) ?? .threeMinutes
        showMenuBarItem = defaults.object(forKey: Key.showMenuBarItem) as? Bool ?? true
        widgetSyncEnabled = defaults.object(forKey: Key.widgetSyncEnabled) as? Bool ?? true
        showMemory = defaults.object(forKey: Key.showMemory) as? Bool ?? true
        showAdvancedDetails = defaults.object(forKey: Key.showAdvancedDetails) as? Bool ?? true
        respectLowPowerMode = defaults.object(forKey: Key.respectLowPowerMode) as? Bool ?? true
        appDisplayName = defaults.string(forKey: Key.appDisplayName) ?? AppConstants.appName
        cpuDisplayName = defaults.string(forKey: Key.cpuDisplayName) ?? "CPU"
        gpuDisplayName = defaults.string(forKey: Key.gpuDisplayName) ?? "GPU"
    }

    var resolvedAppDisplayName: String { cleaned(appDisplayName, fallback: AppConstants.appName) }
    var resolvedCPUDisplayName: String { cleaned(cpuDisplayName, fallback: "CPU") }
    var resolvedGPUDisplayName: String { cleaned(gpuDisplayName, fallback: "GPU") }

    func restoreDefaults() {
        samplingProfile = .balanced
        visualResponse = .calm
        menuBarDisplay = .iconOnly
        gpuSelectionMode = .automatic
        historyWindow = .threeMinutes
        showMenuBarItem = true
        widgetSyncEnabled = true
        showMemory = true
        showAdvancedDetails = true
        respectLowPowerMode = true
        appDisplayName = AppConstants.appName
        cpuDisplayName = "CPU"
        gpuDisplayName = "GPU"
    }

    private func cleaned(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
