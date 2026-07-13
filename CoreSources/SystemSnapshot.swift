import Foundation

enum GPUMetricSource: String, Codable, CaseIterable {
    case appleSiliconIORegistry = "Apple Silicon · AGXAccelerator"
    case ioAccelerator = "Intel/AMD · IOAccelerator"
    case commandFallback = "IORegistry command fallback"
    case unavailable = "Unavailable"
}

enum TelemetryFreshness: String, Codable {
    case live
    case stale
    case unavailable
}

struct CPUSnapshot: Codable, Equatable {
    var usage: Double
    var rawUsage: Double
    var userUsage: Double
    var systemUsage: Double
    var idleUsage: Double
    var logicalCoreCount: Int
    var loadAverage1Minute: Double
    var loadAverage5Minutes: Double
    var loadAverage15Minutes: Double

    static let empty = CPUSnapshot(
        usage: 0,
        rawUsage: 0,
        userUsage: 0,
        systemUsage: 0,
        idleUsage: 100,
        logicalCoreCount: ProcessInfo.processInfo.processorCount,
        loadAverage1Minute: 0,
        loadAverage5Minutes: 0,
        loadAverage15Minutes: 0
    )
}

struct GPUSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var usage: Double?
    var rawUsage: Double?
    var modelName: String
    var vendorName: String?
    var registryClass: String
    var source: GPUMetricSource
    var temperatureCelsius: Double?
    var coreClockMHz: Double?
    var memoryClockMHz: Double?
    var fanRPM: Double?
    var fanPercent: Double?
    var powerWatts: Double?
    var activeMemoryBytes: Double?
    var allocatedMemoryBytes: Double?
    var reclaimableMemoryBytes: Double?
    var freeVRAMBytes: Double?
    var totalVRAMBytes: Double?
    var isStale: Bool
    var lastSuccessfulSample: Date?

    var isAvailable: Bool { usage != nil }
    var freshness: TelemetryFreshness {
        if !isAvailable { return .unavailable }
        return isStale ? .stale : .live
    }

    var detailCount: Int {
        [temperatureCelsius, coreClockMHz, memoryClockMHz, fanRPM, fanPercent, powerWatts,
         activeMemoryBytes, allocatedMemoryBytes, reclaimableMemoryBytes, freeVRAMBytes, totalVRAMBytes]
            .compactMap { $0 }
            .count
    }

    static let unavailable = GPUSnapshot(
        id: "unavailable",
        usage: nil,
        rawUsage: nil,
        modelName: "GPU telemetry unavailable",
        vendorName: nil,
        registryClass: "Unavailable",
        source: .unavailable,
        temperatureCelsius: nil,
        coreClockMHz: nil,
        memoryClockMHz: nil,
        fanRPM: nil,
        fanPercent: nil,
        powerWatts: nil,
        activeMemoryBytes: nil,
        allocatedMemoryBytes: nil,
        reclaimableMemoryBytes: nil,
        freeVRAMBytes: nil,
        totalVRAMBytes: nil,
        isStale: false,
        lastSuccessfulSample: nil
    )
}

struct MemorySnapshot: Codable, Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64
    var cachedBytes: UInt64
    var pressurePercent: Double

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes) * 100, 0), 100)
    }

    static let empty = MemorySnapshot(
        usedBytes: 0,
        totalBytes: ProcessInfo.processInfo.physicalMemory,
        wiredBytes: 0,
        compressedBytes: 0,
        cachedBytes: 0,
        pressurePercent: 0
    )
}

struct PowerSnapshot: Codable, Equatable {
    var totalSystemWatts: Double?
    var cpuPackageWatts: Double?
    var gpuWatts: Double?
    var memoryWatts: Double?
    var sourceDescription: String
    var isEstimated: Bool

    var hasAnyData: Bool {
        totalSystemWatts != nil || cpuPackageWatts != nil || gpuWatts != nil || memoryWatts != nil
    }

    var knownComponentSumWatts: Double? {
        let values = [cpuPackageWatts, gpuWatts, memoryWatts].compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    static let empty = PowerSnapshot(
        totalSystemWatts: nil,
        cpuPackageWatts: nil,
        gpuWatts: nil,
        memoryWatts: nil,
        sourceDescription: "Not exposed by this hardware or driver",
        isEstimated: false
    )
}

struct MachineSnapshot: Codable, Equatable {
    var hardwareModel: String
    var processorName: String
    var architecture: String
    var operatingSystem: String
    var operatingSystemVersion: String
    var activeProcessorCount: Int
    var physicalMemoryBytes: UInt64
    var compatibilityClass: String

    static let empty = MachineSnapshot(
        hardwareModel: "Unknown Mac",
        processorName: "Unknown processor",
        architecture: "unknown",
        operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
        operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        compatibilityClass: "Unknown"
    )
}

struct SystemSnapshot: Codable, Equatable {
    var timestamp: Date
    var sequence: UInt64
    var cpu: CPUSnapshot
    var gpu: GPUSnapshot
    var availableGPUs: [GPUSnapshot]
    var memory: MemorySnapshot
    var power: PowerSnapshot
    var machine: MachineSnapshot
    var thermalState: Int
    var lowPowerModeEnabled: Bool
    var effectiveSamplingInterval: Double
    var sessionUptime: Double

    var isFresh: Bool { Date().timeIntervalSince(timestamp) < 20 }

    static let empty = SystemSnapshot(
        timestamp: .distantPast,
        sequence: 0,
        cpu: .empty,
        gpu: .unavailable,
        availableGPUs: [],
        memory: .empty,
        power: .empty,
        machine: .empty,
        thermalState: 0,
        lowPowerModeEnabled: false,
        effectiveSamplingInterval: 0,
        sessionUptime: 0
    )
}

struct MetricHistoryPoint: Codable, Equatable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let cpuUsage: Double
    let gpuUsage: Double?
    let memoryUsage: Double
}

struct SharedPayload: Codable, Equatable {
    let schemaVersion: Int
    var snapshot: SystemSnapshot
    var history: [MetricHistoryPoint]

    static let empty = SharedPayload(
        schemaVersion: AppConstants.payloadSchemaVersion,
        snapshot: .empty,
        history: []
    )
}
