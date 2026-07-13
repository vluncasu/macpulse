import Foundation
import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var monitor: MonitorStore
    @ObservedObject var settings: SettingsStore
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private let cpuTint = Color.accentColor
    private let gpuTint = Color.purple
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                overviewCard
                powerCard
                historyCard
                cpuBreakdownCard
                if settings.showMemory { memoryCard }
                if monitor.snapshot.availableGPUs.count > 1 { multiGPUCard }
                if settings.showAdvancedDetails { gpuDetailsCard }
                footer
            }
            .padding(16)
        }
        .frame(width: 452, height: 690)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.001))
        .onAppear { monitor.setDashboardVisible(true) }
        .onDisappear { monitor.setDashboardVisible(false) }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(0.055))
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.resolvedAppDisplayName)
                    .font(.headline)
                Text("\(monitor.snapshot.machine.hardwareModel) · \(monitor.snapshot.machine.architecture)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(monitor.samplingState.rawValue)
                        .font(.caption.weight(.medium))
                }
                Text(intervalText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
    }

    private var overviewCard: some View {
        HStack(spacing: 42) {
            RingMetricView(
                title: settings.resolvedCPUDisplayName,
                value: monitor.snapshot.cpu.usage,
                subtitle: "\(monitor.snapshot.cpu.logicalCoreCount) logical cores",
                tint: cpuTint
            )
            RingMetricView(
                title: settings.resolvedGPUDisplayName,
                value: monitor.snapshot.gpu.usage,
                subtitle: gpuSubtitle,
                tint: gpuTint
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .cardSurface()
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Power", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(monitor.snapshot.power.isEstimated ? "Estimated" : "Live")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MetricDetailView(
                    symbol: "bolt.circle",
                    title: "Total system",
                    value: optionalValue(monitor.snapshot.power.totalSystemWatts, suffix: " W")
                )
                MetricDetailView(
                    symbol: "bolt.fill",
                    title: settings.resolvedGPUDisplayName + " power",
                    value: optionalValue(monitor.snapshot.power.gpuWatts, suffix: " W")
                )
                MetricDetailView(
                    symbol: "cpu",
                    title: settings.resolvedCPUDisplayName + " package",
                    value: optionalValue(monitor.snapshot.power.cpuPackageWatts, suffix: " W")
                )
                MetricDetailView(
                    symbol: "memorychip",
                    title: "Memory power",
                    value: optionalValue(monitor.snapshot.power.memoryWatts, suffix: " W")
                )
            }

            Text(monitor.snapshot.power.sourceDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(13)
        .cardSurface()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Recent activity")
                    .font(.caption.weight(.semibold))
                Spacer()
                legend(title: settings.resolvedCPUDisplayName, color: cpuTint)
                legend(title: settings.resolvedGPUDisplayName, color: gpuTint)
            }

            ZStack {
                horizontalGrid
                SparklineView(values: cpuHistory, tint: cpuTint)
                SparklineView(values: gpuHistory, tint: gpuTint)
            }
            .frame(height: 62)
        }
        .padding(13)
        .cardSurface()
    }

    private var horizontalGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Divider().opacity(index == 3 ? 0 : 0.35)
                if index < 3 { Spacer() }
            }
        }
    }

    private var cpuBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(settings.resolvedCPUDisplayName) composition", systemImage: "cpu")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(String(format: "Load %.2f", monitor.snapshot.cpu.loadAverage1Minute))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            percentageBar(title: "User", value: monitor.snapshot.cpu.userUsage, tint: cpuTint)
            percentageBar(title: "System", value: monitor.snapshot.cpu.systemUsage, tint: .orange)
        }
        .padding(13)
        .cardSurface()
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(byteString(monitor.snapshot.memory.usedBytes)) / \(byteString(monitor.snapshot.memory.totalBytes))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            percentageBar(title: "Used", value: monitor.snapshot.memory.usagePercent, tint: .cyan)
            HStack {
                smallValue("Wired", byteString(monitor.snapshot.memory.wiredBytes))
                Spacer()
                smallValue("Compressed", byteString(monitor.snapshot.memory.compressedBytes))
                Spacer()
                smallValue("Cached", byteString(monitor.snapshot.memory.cachedBytes))
            }
        }
        .padding(13)
        .cardSurface()
    }

    private var multiGPUCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Detected graphics devices", systemImage: "rectangle.3.group")
                .font(.caption.weight(.semibold))

            ForEach(monitor.snapshot.availableGPUs) { gpu in
                HStack(spacing: 9) {
                    Image(systemName: gpu.id == monitor.snapshot.gpu.id ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(gpu.id == monitor.snapshot.gpu.id ? gpuTint : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(gpu.modelName).font(.caption.weight(.medium)).lineLimit(1)
                        Text(gpu.source.rawValue).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(gpu.usage.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
        }
        .padding(13)
        .cardSurface()
    }

    private var gpuDetailsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("\(settings.resolvedGPUDisplayName) telemetry", systemImage: "waveform.path.ecg")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(monitor.snapshot.gpu.freshness.rawValue.capitalized)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(monitor.snapshot.gpu.isStale ? Color.orange : Color.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MetricDetailView(symbol: "cpu", title: "Model", value: monitor.snapshot.gpu.modelName)
                MetricDetailView(symbol: "thermometer.medium", title: "Temperature", value: optionalValue(monitor.snapshot.gpu.temperatureCelsius, suffix: " °C"))
                MetricDetailView(symbol: "speedometer", title: "Core clock", value: optionalValue(monitor.snapshot.gpu.coreClockMHz, suffix: " MHz"))
                MetricDetailView(symbol: "memorychip", title: "Memory clock", value: optionalValue(monitor.snapshot.gpu.memoryClockMHz, suffix: " MHz"))
                MetricDetailView(symbol: "bolt.fill", title: "Power", value: optionalValue(monitor.snapshot.gpu.powerWatts, suffix: " W"))
                MetricDetailView(symbol: "fan", title: "Fan", value: fanText)
                MetricDetailView(symbol: "square.stack.3d.up", title: "GPU memory", value: gpuMemoryText)
                MetricDetailView(symbol: "externaldrive", title: "Reclaimable cache", value: optionalBytes(monitor.snapshot.gpu.reclaimableMemoryBytes))
            }
        }
        .padding(13)
        .cardSurface()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Group {
                if monitor.snapshot.timestamp == .distantPast {
                    Text("Waiting for first sample")
                } else {
                    HStack(spacing: 3) {
                        Text("Updated")
                        Text(monitor.snapshot.timestamp, style: .relative)
                        Text("ago")
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            Spacer()

            Button {
                monitor.forceRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh now")

            Button("Settings…", action: onOpenSettings)
                .buttonStyle(.borderless)
            Button("Quit", action: onQuit)
                .buttonStyle(.borderless)
        }
    }

    private func percentageBar(title: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 9) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.07))
                    Capsule()
                        .fill(tint.opacity(0.86))
                        .frame(width: proxy.size.width * min(max(value / 100, 0), 1))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.65), value: value)
                }
            }
            .frame(height: 7)
            Text("\(Int(value.rounded()))%")
                .font(.caption2.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func smallValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.caption2.weight(.medium)).monospacedDigit()
        }
    }

    private func legend(title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch monitor.samplingState {
        case .live: return .green
        case .adaptive: return .blue
        case .lowPower: return .yellow
        case .thermal: return .orange
        case .paused: return .secondary
        }
    }

    private var intervalText: String {
        guard monitor.isRunning else { return "Monitoring stopped" }
        return String(format: "%.1f s sampling", monitor.snapshot.effectiveSamplingInterval)
    }

    private var gpuSubtitle: String {
        if monitor.snapshot.gpu.isStale { return "Holding last valid sample" }
        if !monitor.snapshot.gpu.isAvailable { return "Driver does not expose activity" }
        return monitor.snapshot.gpu.modelName
    }

    private var cpuHistory: [Double] { monitor.history.suffix(120).map(\.cpuUsage) }
    private var gpuHistory: [Double] { monitor.history.suffix(120).map { $0.gpuUsage ?? 0 } }

    private var fanText: String {
        if let rpm = monitor.snapshot.gpu.fanRPM { return "\(Int(rpm.rounded())) RPM" }
        if let percent = monitor.snapshot.gpu.fanPercent { return "\(Int(percent.rounded()))%" }
        return "Not exposed"
    }

    private var gpuMemoryText: String {
        if let active = monitor.snapshot.gpu.activeMemoryBytes,
           let total = monitor.snapshot.gpu.totalVRAMBytes,
           total > 0 {
            return "\(byteString(active)) / \(byteString(total))"
        }
        if let active = monitor.snapshot.gpu.activeMemoryBytes { return byteString(active) }
        if let free = monitor.snapshot.gpu.freeVRAMBytes { return "\(byteString(free)) free" }
        return "Not exposed"
    }

    private func optionalValue(_ value: Double?, suffix: String) -> String {
        value.map { "\(Int($0.rounded()))\(suffix)" } ?? "Not exposed"
    }

    private func optionalBytes(_ value: Double?) -> String {
        value.map(byteString) ?? "Not exposed"
    }

    private func byteString(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private func byteString(_ bytes: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(bytes, 0)), countStyle: .memory)
    }
}

private extension View {
    func cardSurface() -> some View {
        background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(.primary.opacity(0.045), lineWidth: 0.5)
            }
    }
}
