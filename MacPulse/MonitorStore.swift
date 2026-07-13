import Combine
import Foundation
import WidgetKit

enum SamplingState: String {
    case live = "Live"
    case adaptive = "Adaptive"
    case lowPower = "Low Power"
    case thermal = "Thermal protection"
    case paused = "Paused"
}

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var snapshot: SystemSnapshot
    @Published private(set) var history: [MetricHistoryPoint]
    @Published private(set) var isRunning = false
    @Published private(set) var isDashboardVisible = false
    @Published private(set) var samplingState: SamplingState = .paused
    @Published private(set) var lastPersistenceSucceeded = true

    private let settings: SettingsStore
    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()
    private let powerReader = PowerReader()
    private let machine = MachineReader().read()
    private let sessionStartedAt = Date()

    private var cpuSmoother = MetricSmoother()
    private var gpuSmoother = MetricSmoother()
    private var loopTask: Task<Void, Never>?
    private var isSampling = false
    private var sequence: UInt64 = 0
    private var lastGPURead = Date.distantPast
    private var lastPersist = Date.distantPast
    private var lastWidgetReload = Date.distantPast
    private var lastWidgetReloadSnapshot = SystemSnapshot.empty
    private var lastHistoryAppend = Date.distantPast
    private var lastRawGPU: GPUSnapshot = .unavailable
    private var lastGPUDevices: [GPUSnapshot] = []
    private var lastPrimaryGPUIdentifier: String?
    private var lastValidGPUDate = Date.distantPast
    private var consecutiveIdleSamples = 0
    private var effectiveLoopInterval: TimeInterval = 1.5
    private var wasRunningBeforeSleep = false

    init(settings: SettingsStore) {
        self.settings = settings
        let cached = SharedSnapshotStore.load() ?? .empty
        snapshot = cached.snapshot
        history = cached.history
        if snapshot.machine == .empty { snapshot.machine = machine }
        cpuReader.prime()
    }

    deinit { loopTask?.cancel() }

    func start() {
        guard loopTask == nil else { return }
        isRunning = true
        updateSamplingState()
        loopTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.sampleOnce()
                let delay = self.currentLoopInterval()
                self.effectiveLoopInterval = delay
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
        samplingState = .paused
        persist(forceWidgetReload: false)
    }

    func toggleRunning() {
        isRunning ? stop() : start()
    }

    func pauseForSleep() {
        wasRunningBeforeSleep = isRunning
        stop()
    }

    func resumeAfterWake() {
        cpuReader.prime()
        cpuSmoother.reset()
        gpuSmoother.reset()
        consecutiveIdleSamples = 0
        if wasRunningBeforeSleep { start() }
        wasRunningBeforeSleep = false
    }

    func setDashboardVisible(_ visible: Bool) {
        isDashboardVisible = visible
        updateSamplingState()
        if visible { Task { await sampleOnce(forceGPU: true) } }
    }

    func forceRefresh() {
        Task { await sampleOnce(forceGPU: true, forcePersistence: true) }
    }

    func diagnosticsJSON() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let dictionary: [String: Any] = [
            "application": ["name": settings.resolvedAppDisplayName, "version": version, "build": build],
            "generatedAt": ISO8601DateFormatter().string(from: .now),
            "sampling": [
                "running": isRunning,
                "state": samplingState.rawValue,
                "profile": settings.samplingProfile.rawValue,
                "effectiveIntervalSeconds": effectiveLoopInterval,
                "dashboardVisible": isDashboardVisible,
                "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
                "thermalState": ProcessInfo.processInfo.thermalState.rawValue
            ],
            "machine": [
                "hardwareModel": machine.hardwareModel,
                "processor": machine.processorName,
                "architecture": machine.architecture,
                "operatingSystem": machine.operatingSystemVersion,
                "compatibilityClass": machine.compatibilityClass
            ],
            "power": [
                "totalSystemWatts": (snapshot.power.totalSystemWatts as Any?) ?? NSNull(),
                "cpuPackageWatts": (snapshot.power.cpuPackageWatts as Any?) ?? NSNull(),
                "gpuWatts": (snapshot.power.gpuWatts as Any?) ?? NSNull(),
                "memoryWatts": (snapshot.power.memoryWatts as Any?) ?? NSNull(),
                "knownComponentSumWatts": (snapshot.power.knownComponentSumWatts as Any?) ?? NSNull(),
                "source": snapshot.power.sourceDescription,
                "estimated": snapshot.power.isEstimated
            ],
            "gpu": snapshot.availableGPUs.map { gpu in
                [
                    "id": gpu.id,
                    "model": gpu.modelName,
                    "vendor": (gpu.vendorName as Any?) ?? NSNull(),
                    "registryClass": gpu.registryClass,
                    "source": gpu.source.rawValue,
                    "usagePercent": (gpu.rawUsage as Any?) ?? NSNull(),
                    "temperatureCelsius": (gpu.temperatureCelsius as Any?) ?? NSNull(),
                    "coreClockMHz": (gpu.coreClockMHz as Any?) ?? NSNull(),
                    "memoryClockMHz": (gpu.memoryClockMHz as Any?) ?? NSNull(),
                    "powerWatts": (gpu.powerWatts as Any?) ?? NSNull(),
                    "fanRPM": (gpu.fanRPM as Any?) ?? NSNull(),
                    "activeMemoryBytes": (gpu.activeMemoryBytes as Any?) ?? NSNull(),
                    "reclaimableMemoryBytes": (gpu.reclaimableMemoryBytes as Any?) ?? NSNull()
                ] as [String: Any]
            },
            "persistence": [
                "storage": "Application Support / local UserDefaults",
                "widgetAcquisition": "independent on-device sampling",
                "lastWriteSucceeded": lastPersistenceSucceeded,
                "payloadSchema": AppConstants.payloadSchemaVersion
            ]
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: dictionary,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private func sampleOnce(
        forceGPU: Bool = false,
        forcePersistence: Bool = false
    ) async {
        guard !isSampling else { return }
        isSampling = true
        defer { isSampling = false }

        let now = Date()
        var cpu = cpuReader.read()
        cpu.usage = cpuSmoother.update(
            rawValue: cpu.rawUsage,
            at: now,
            enabled: settings.visualResponse.smoothingEnabled,
            attackTime: settings.visualResponse.attackTime,
            releaseTime: settings.visualResponse.releaseTime
        )
        let memory = memoryReader.read()

        let shouldReadGPU = forceGPU || now.timeIntervalSince(lastGPURead) >= currentGPUInterval()
        if shouldReadGPU {
            lastGPURead = now
            let selectionMode = settings.gpuSelectionMode
            let previousID = lastPrimaryGPUIdentifier
            let result = await Task.detached(priority: .utility) {
                GPUReader().read(selectionMode: selectionMode, previousPrimaryID: previousID)
            }.value
            mergeGPURead(result, at: now)
        }

        var gpu = lastRawGPU
        if let rawUsage = gpu.rawUsage ?? gpu.usage {
            if gpu.id != lastPrimaryGPUIdentifier {
                gpuSmoother.reset()
            }
            gpu.usage = gpuSmoother.update(
                rawValue: rawUsage,
                at: now,
                enabled: settings.visualResponse.smoothingEnabled,
                attackTime: settings.visualResponse.attackTime,
                releaseTime: settings.visualResponse.releaseTime,
                maximumRiseRate: 90,
                maximumFallRate: 52
            )
        }
        lastPrimaryGPUIdentifier = gpu.id

        let power = powerReader.read(gpu: gpu)

        sequence &+= 1
        snapshot = SystemSnapshot(
            timestamp: now,
            sequence: sequence,
            cpu: cpu,
            gpu: gpu,
            availableGPUs: lastGPUDevices,
            memory: memory,
            power: power,
            machine: machine,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            effectiveSamplingInterval: effectiveLoopInterval,
            sessionUptime: now.timeIntervalSince(sessionStartedAt)
        )

        updateIdleState()
        updateSamplingState()
        appendHistoryIfNeeded(at: now)

        if forcePersistence || now.timeIntervalSince(lastPersist) >= 2 {
            persist(forceWidgetReload: forcePersistence)
            lastPersist = now
        }
    }

    private func mergeGPURead(_ result: GPUReadResult, at date: Date) {
        guard !result.devices.isEmpty else {
            guard lastRawGPU.isAvailable, date.timeIntervalSince(lastValidGPUDate) < 15 else {
                lastRawGPU = .unavailable
                lastGPUDevices = []
                return
            }
            lastRawGPU.isStale = true
            lastGPUDevices = lastGPUDevices.map { device in
                var copy = device
                copy.isStale = true
                return copy
            }
            return
        }

        lastGPUDevices = result.devices
        var primary = result.primary
        if primary.isAvailable {
            primary.rawUsage = primary.rawUsage ?? primary.usage
            primary.isStale = false
            primary.lastSuccessfulSample = date
            lastValidGPUDate = date
        } else if lastRawGPU.isAvailable, date.timeIntervalSince(lastValidGPUDate) < 15 {
            primary = lastRawGPU
            primary.isStale = true
        }
        lastRawGPU = primary
    }

    private func appendHistoryIfNeeded(at date: Date) {
        guard date.timeIntervalSince(lastHistoryAppend) >= 1 else { return }
        lastHistoryAppend = date
        history.append(MetricHistoryPoint(
            timestamp: date,
            cpuUsage: snapshot.cpu.usage,
            gpuUsage: snapshot.gpu.usage,
            memoryUsage: snapshot.memory.usagePercent
        ))

        let maximum = settings.historyWindow.rawValue
        if history.count > maximum { history.removeFirst(history.count - maximum) }
    }

    private func updateIdleState() {
        let gpu = snapshot.gpu.rawUsage ?? snapshot.gpu.usage ?? 0
        if snapshot.cpu.rawUsage < 6, gpu < 6, !isDashboardVisible {
            consecutiveIdleSamples = min(consecutiveIdleSamples + 1, 10_000)
        } else {
            consecutiveIdleSamples = 0
        }
    }

    private func updateSamplingState() {
        guard isRunning else { samplingState = .paused; return }
        let process = ProcessInfo.processInfo
        if process.thermalState == .serious || process.thermalState == .critical {
            samplingState = .thermal
        } else if settings.respectLowPowerMode, process.isLowPowerModeEnabled {
            samplingState = .lowPower
        } else if isDashboardVisible || consecutiveIdleSamples < 8 {
            samplingState = .live
        } else {
            samplingState = .adaptive
        }
    }

    private var currentThermalCondition: ThermalCondition {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
    }

    private func currentLoopInterval() -> TimeInterval {
        AdaptiveSamplingPolicy.loopInterval(
            profile: settings.samplingProfile,
            dashboardVisible: isDashboardVisible,
            idleSamples: consecutiveIdleSamples,
            lowPowerMode: settings.respectLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalCondition: currentThermalCondition
        )
    }

    private func currentGPUInterval() -> TimeInterval {
        AdaptiveSamplingPolicy.gpuInterval(
            profile: settings.samplingProfile,
            dashboardVisible: isDashboardVisible,
            idleSamples: consecutiveIdleSamples,
            lowPowerMode: settings.respectLowPowerMode && ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalCondition: currentThermalCondition
        )
    }

    private func persist(forceWidgetReload: Bool) {
        let payload = SharedPayload(
            schemaVersion: AppConstants.payloadSchemaVersion,
            snapshot: snapshot,
            history: downsampledHistory(history, maximumCount: AppConstants.maximumPersistedHistoryPoints)
        )
        lastPersistenceSucceeded = SharedSnapshotStore.save(payload)

        guard settings.widgetSyncEnabled else { return }
        let now = Date()
        let minimumGap: TimeInterval = 120
        let heartbeat: TimeInterval = 10 * 60
        let significant = widgetChangeIsSignificant(from: lastWidgetReloadSnapshot, to: snapshot)
        let shouldReload = forceWidgetReload
            || now.timeIntervalSince(lastWidgetReload) >= heartbeat
            || (significant && now.timeIntervalSince(lastWidgetReload) >= minimumGap)
        guard shouldReload else { return }

        lastWidgetReload = now
        lastWidgetReloadSnapshot = snapshot
        AppConstants.allWidgetKinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
    }

    private func widgetChangeIsSignificant(from old: SystemSnapshot, to new: SystemSnapshot) -> Bool {
        if old.timestamp == .distantPast { return true }
        if abs(old.cpu.usage - new.cpu.usage) >= 15 { return true }
        if abs((old.gpu.usage ?? 0) - (new.gpu.usage ?? 0)) >= 15 { return true }
        if old.gpu.freshness != new.gpu.freshness { return true }
        if old.lowPowerModeEnabled != new.lowPowerModeEnabled { return true }
        if old.thermalState != new.thermalState { return true }
        return false
    }

    private func downsampledHistory(
        _ points: [MetricHistoryPoint],
        maximumCount: Int
    ) -> [MetricHistoryPoint] {
        guard points.count > maximumCount, maximumCount > 1 else { return points }
        let stride = Double(points.count - 1) / Double(maximumCount - 1)
        return (0..<maximumCount).map { index in
            points[min(Int((Double(index) * stride).rounded()), points.count - 1)]
        }
    }
}
