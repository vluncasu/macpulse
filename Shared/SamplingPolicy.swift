import Foundation

enum SamplingProfile: String, CaseIterable, Identifiable {
    case responsive
    case balanced
    case efficient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .responsive: return "Responsive"
        case .balanced: return "Balanced"
        case .efficient: return "Efficient"
        }
    }

    var explanation: String {
        switch self {
        case .responsive: return "Fastest live response with a moderate background cost."
        case .balanced: return "Adaptive sampling designed for everyday use."
        case .efficient: return "Lower-frequency background sampling for battery-sensitive systems."
        }
    }
}

enum ThermalCondition: Int, CaseIterable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
}

struct AdaptiveSamplingPolicy {
    static func loopInterval(
        profile: SamplingProfile,
        dashboardVisible: Bool,
        idleSamples: Int,
        lowPowerMode: Bool,
        thermalCondition: ThermalCondition
    ) -> TimeInterval {
        if thermalCondition == .critical { return dashboardVisible ? 2.0 : 12.0 }
        if thermalCondition == .serious { return dashboardVisible ? 1.5 : 8.0 }
        if lowPowerMode, !dashboardVisible { return 6.0 }

        switch profile {
        case .responsive:
            return dashboardVisible ? 0.5 : (idleSamples > 16 ? 2.0 : 0.9)
        case .balanced:
            return dashboardVisible ? 0.75 : (idleSamples > 12 ? 3.0 : 1.4)
        case .efficient:
            return dashboardVisible ? 1.1 : (idleSamples > 8 ? 6.0 : 2.8)
        }
    }

    static func gpuInterval(
        profile: SamplingProfile,
        dashboardVisible: Bool,
        idleSamples: Int,
        lowPowerMode: Bool,
        thermalCondition: ThermalCondition
    ) -> TimeInterval {
        if thermalCondition == .critical { return dashboardVisible ? 3.0 : 18.0 }
        if thermalCondition == .serious { return dashboardVisible ? 2.0 : 12.0 }
        if lowPowerMode, !dashboardVisible { return 10.0 }

        switch profile {
        case .responsive:
            return dashboardVisible ? 0.65 : (idleSamples > 16 ? 4.0 : 1.3)
        case .balanced:
            return dashboardVisible ? 0.9 : (idleSamples > 12 ? 6.0 : 2.2)
        case .efficient:
            return dashboardVisible ? 1.6 : (idleSamples > 8 ? 12.0 : 4.5)
        }
    }
}
