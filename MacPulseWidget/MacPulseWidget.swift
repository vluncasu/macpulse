import Foundation
import AppKit
import SwiftUI
import WidgetKit

struct MacPulseEntry: TimelineEntry {
    let date: Date
    let payload: SharedPayload

    var snapshot: SystemSnapshot { payload.snapshot }
    var history: [MetricHistoryPoint] { payload.history }
}


private enum WidgetMetricSampler {
    private static let historyKey = "widget.metricHistory.v1"
    private static let historyLimit = 90

    static func sample() async -> SharedPayload {
        let now = Date()
        let cpuReader = CPUReader()
        cpuReader.prime()

        let gpuTask = Task.detached(priority: .utility) {
            GPUReader().read(allowCommandFallback: false)
        }

        // CPU utilization is a delta measurement. A short, bounded observation
        // window produces a useful reading without keeping the extension alive.
        try? await Task.sleep(nanoseconds: 250_000_000)

        let cpu = cpuReader.read()
        let gpuResult = await gpuTask.value
        let gpu = gpuResult.primary
        let memory = MemoryReader().read()
        let machine = MachineReader().read()
        let power = PowerReader().read(gpu: gpu)

        let snapshot = SystemSnapshot(
            timestamp: now,
            sequence: UInt64(now.timeIntervalSince1970 * 1_000),
            cpu: cpu,
            gpu: gpu,
            availableGPUs: gpuResult.devices,
            memory: memory,
            power: power,
            machine: machine,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            effectiveSamplingInterval: 15 * 60,
            sessionUptime: ProcessInfo.processInfo.systemUptime
        )

        return SharedPayload(
            schemaVersion: AppConstants.payloadSchemaVersion,
            snapshot: snapshot,
            history: appendHistory(for: snapshot)
        )
    }

    private static func appendHistory(for snapshot: SystemSnapshot) -> [MetricHistoryPoint] {
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        var history: [MetricHistoryPoint] = []

        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? decoder.decode([MetricHistoryPoint].self, from: data) {
            history = decoded
        }

        history.append(MetricHistoryPoint(
            timestamp: snapshot.timestamp,
            cpuUsage: snapshot.cpu.usage,
            gpuUsage: snapshot.gpu.usage,
            memoryUsage: snapshot.memory.usagePercent
        ))

        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }

        if let data = try? encoder.encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        return history
    }
}

struct MacPulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacPulseEntry {
        MacPulseEntry(date: .now, payload: previewPayload)
    }

    func getSnapshot(in context: Context, completion: @escaping (MacPulseEntry) -> Void) {
        guard !context.isPreview else {
            completion(MacPulseEntry(date: .now, payload: previewPayload))
            return
        }

        Task {
            let payload = await WidgetMetricSampler.sample()
            completion(MacPulseEntry(date: .now, payload: payload))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacPulseEntry>) -> Void) {
        Task {
            let payload = await WidgetMetricSampler.sample()
            let entry = MacPulseEntry(date: .now, payload: payload)
            let nextRefresh = Date().addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    private var previewPayload: SharedPayload {
        let now = Date()
        let points = (0..<60).map { index in
            MetricHistoryPoint(
                timestamp: now.addingTimeInterval(Double(index - 60)),
                cpuUsage: 28 + sin(Double(index) / 7) * 13,
                gpuUsage: 17 + sin(Double(index) / 9) * 10,
                memoryUsage: 58
            )
        }
        var snapshot = SystemSnapshot.empty
        snapshot.timestamp = now
        snapshot.cpu = CPUSnapshot(
            usage: 34,
            rawUsage: 36,
            userUsage: 24,
            systemUsage: 10,
            idleUsage: 66,
            logicalCoreCount: 10,
            loadAverage1Minute: 2.1,
            loadAverage5Minutes: 1.8,
            loadAverage15Minutes: 1.5
        )
        snapshot.gpu = GPUSnapshot(
            id: "preview-gpu",
            usage: 22,
            rawUsage: 24,
            modelName: "Graphics processor",
            vendorName: "Apple",
            registryClass: "AGXAccelerator",
            source: .appleSiliconIORegistry,
            temperatureCelsius: 52,
            coreClockMHz: nil,
            memoryClockMHz: nil,
            fanRPM: nil,
            fanPercent: nil,
            powerWatts: nil,
            activeMemoryBytes: 1_400_000_000,
            allocatedMemoryBytes: 2_000_000_000,
            reclaimableMemoryBytes: nil,
            freeVRAMBytes: nil,
            totalVRAMBytes: nil,
            isStale: false,
            lastSuccessfulSample: now
        )
        snapshot.availableGPUs = [snapshot.gpu]
        snapshot.memory = MemorySnapshot(
            usedBytes: 9_200_000_000,
            totalBytes: 16_000_000_000,
            wiredBytes: 2_100_000_000,
            compressedBytes: 1_000_000_000,
            cachedBytes: 3_000_000_000,
            pressurePercent: 19
        )
        snapshot.machine = .empty
        snapshot.power = PowerSnapshot(
            totalSystemWatts: 24,
            cpuPackageWatts: nil,
            gpuWatts: 7,
            memoryWatts: nil,
            sourceDescription: "Preview data",
            isEstimated: false
        )
        snapshot.effectiveSamplingInterval = 1.4
        return SharedPayload(
            schemaVersion: AppConstants.payloadSchemaVersion,
            snapshot: snapshot,
            history: points
        )
    }
}

private enum FocusMetric {
    case cpu
    case gpu
}

struct OverviewWidgetView: View {
    let entry: MacPulseEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                small
            case .systemMedium:
                medium
            default:
                large
            }
        }
        .widgetURL(URL(string: "macpulse://open"))
        .macPulseWidgetBackground()
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetHeader(compact: true)
            HStack(spacing: 14) {
                WidgetRing(title: "CPU", value: entry.snapshot.cpu.usage, tint: .accentColor)
                WidgetRing(title: "GPU", value: entry.snapshot.gpu.usage, tint: .purple)
            }
            Spacer(minLength: 0)
            freshnessLine
        }
        .padding(14)
    }

    private var medium: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                widgetHeader(compact: false)
                HStack(spacing: 16) {
                    WidgetRing(title: "CPU", value: entry.snapshot.cpu.usage, tint: .accentColor, diameter: 72)
                    WidgetRing(title: "GPU", value: entry.snapshot.gpu.usage, tint: .purple, diameter: 72)
                }
            }
            Divider().opacity(0.55)
            VStack(alignment: .leading, spacing: 10) {
                WidgetValue(title: "Memory", value: "\(Int(entry.snapshot.memory.usagePercent.rounded()))%", symbol: "memorychip")
                WidgetValue(title: "Temperature", value: temperatureText, symbol: "thermometer.medium")
                WidgetValue(title: "State", value: stateText, symbol: "waveform.path.ecg")
                freshnessLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetHeader(compact: false)
            HStack(spacing: 22) {
                WidgetRing(title: "CPU", value: entry.snapshot.cpu.usage, tint: .accentColor, diameter: 100)
                WidgetRing(title: "GPU", value: entry.snapshot.gpu.usage, tint: .purple, diameter: 100)
                VStack(alignment: .leading, spacing: 9) {
                    WidgetValue(title: "Memory", value: "\(Int(entry.snapshot.memory.usagePercent.rounded()))%", symbol: "memorychip")
                    WidgetValue(title: "GPU temperature", value: temperatureText, symbol: "thermometer.medium")
                    WidgetValue(title: "Sampling", value: String(format: "%.1f s", entry.snapshot.effectiveSamplingInterval), symbol: "timer")
                    WidgetValue(title: "Power", value: powerText, symbol: "bolt.fill")
                    WidgetValue(title: "Telemetry", value: entry.snapshot.gpu.freshness.rawValue.capitalized, symbol: "dot.radiowaves.left.and.right")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Recent activity").font(.caption.weight(.semibold))
                    Spacer()
                    legend("CPU", .accentColor)
                    legend("GPU", .purple)
                }
                ZStack {
                    WidgetSparkline(values: entry.history.suffix(90).map(\.cpuUsage), tint: .accentColor)
                    WidgetSparkline(values: entry.history.suffix(90).map { $0.gpuUsage ?? 0 }, tint: .purple)
                }
                .frame(height: 76)
            }

            HStack {
                Text(entry.snapshot.gpu.modelName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                freshnessLine
            }
        }
        .padding(16)
    }

    private func widgetHeader(compact: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
            Text("MacPulse")
                .font(compact ? .caption.weight(.semibold) : .headline)
            Spacer()
            if !compact {
                Circle()
                    .fill(entry.snapshot.isFresh ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var freshnessLine: some View {
        Group {
            if entry.snapshot.timestamp == .distantPast {
                Text("Open MacPulse")
            } else {
                HStack(spacing: 2) {
                    Text("Updated")
                    Text(entry.snapshot.timestamp, style: .relative)
                    Text("ago")
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var temperatureText: String {
        entry.snapshot.gpu.temperatureCelsius.map { "\(Int($0.rounded())) °C" } ?? "Not exposed"
    }

    private var powerText: String {
        if let total = entry.snapshot.power.totalSystemWatts {
            return "\(Int(total.rounded())) W"
        }
        if let known = entry.snapshot.power.knownComponentSumWatts {
            return "\(Int(known.rounded())) W"
        }
        return "Not exposed"
    }

    private var stateText: String {
        if entry.snapshot.lowPowerModeEnabled { return "Low Power" }
        switch entry.snapshot.thermalState {
        case 2: return "Thermal"
        case 3: return "Critical"
        default: return entry.snapshot.isFresh ? "Live" : "Cached"
        }
    }

    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct FocusWidgetView: View {
    let entry: MacPulseEntry
    let metric: FocusMetric
    @Environment(\.widgetFamily) private var family

    private var value: Double? {
        metric == .cpu ? entry.snapshot.cpu.usage : entry.snapshot.gpu.usage
    }

    private var title: String { metric == .cpu ? "CPU" : "GPU" }
    private var tint: Color { metric == .cpu ? .accentColor : .purple }

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    Spacer(minLength: 0)
                    WidgetRing(title: title, value: value, tint: tint, diameter: 92)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                    detailLine
                }
                .padding(14)
            } else {
                HStack(spacing: 18) {
                    WidgetRing(title: title, value: value, tint: tint, diameter: 104)
                    VStack(alignment: .leading, spacing: 10) {
                        header
                        Text(detailTitle).font(.headline).lineLimit(2)
                        detailLine
                        WidgetSparkline(values: historyValues, tint: tint)
                            .frame(height: 42)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(15)
            }
        }
        .widgetURL(URL(string: "macpulse://open"))
        .macPulseWidgetBackground()
    }

    private var header: some View {
        HStack {
            Image(systemName: metric == .cpu ? "cpu" : "display")
            Text("MacPulse · \(title)").font(.caption.weight(.semibold))
            Spacer()
        }
    }

    private var detailTitle: String {
        metric == .cpu
            ? "\(entry.snapshot.cpu.logicalCoreCount) logical cores"
            : entry.snapshot.gpu.modelName
    }

    private var detailLineText: String {
        if metric == .cpu {
            return String(format: "Load %.2f", entry.snapshot.cpu.loadAverage1Minute)
        }
        return entry.snapshot.gpu.freshness.rawValue.capitalized
    }

    private var detailLine: some View {
        Text(detailLineText)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var historyValues: [Double] {
        metric == .cpu
            ? entry.history.suffix(90).map(\.cpuUsage)
            : entry.history.suffix(90).map { $0.gpuUsage ?? 0 }
    }
}

private struct WidgetRing: View {
    let title: String
    let value: Double?
    let tint: Color
    var diameter: CGFloat = 64

    private var fraction: Double { min(max((value ?? 0) / 100, 0), 1) }

    var body: some View {
        ZStack {
            Circle().stroke(.primary.opacity(0.08), lineWidth: max(diameter * 0.09, 6))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: max(diameter * 0.09, 6), lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(.system(size: diameter * 0.25, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(title)
                    .font(.system(size: max(diameter * 0.1, 8), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct WidgetValue: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 15)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.medium)).monospacedDigit().lineLimit(1)
            }
        }
    }
}

private struct WidgetSparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            var path = Path()
            let step = size.width / CGFloat(values.count - 1)
            for (index, value) in values.enumerated() {
                let point = CGPoint(
                    x: CGFloat(index) * step,
                    y: size.height - CGFloat(min(max(value / 100, 0), 1)) * size.height
                )
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

private extension View {
    @ViewBuilder
    func macPulseWidgetBackground() -> some View {
        if #available(macOSApplicationExtension 14.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct MacPulseOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.overviewWidgetKind, provider: MacPulseProvider()) { entry in
            OverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("MacPulse Overview")
        .description("CPU, GPU, memory, telemetry state, and recent activity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct MacPulseCPUWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.cpuWidgetKind, provider: MacPulseProvider()) { entry in
            FocusWidgetView(entry: entry, metric: .cpu)
        }
        .configurationDisplayName("MacPulse CPU")
        .description("A focused CPU activity gauge.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacPulseGPUWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.gpuWidgetKind, provider: MacPulseProvider()) { entry in
            FocusWidgetView(entry: entry, metric: .gpu)
        }
        .configurationDisplayName("MacPulse GPU")
        .description("A focused GPU activity gauge with driver availability.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MacPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacPulseOverviewWidget()
        MacPulseCPUWidget()
        MacPulseGPUWidget()
    }
}
