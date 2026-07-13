import Darwin
import Foundation

final class CPUReader {
    private struct Ticks {
        let user: UInt64
        let system: UInt64
        let idle: UInt64
        let nice: UInt64
    }

    private var previous: Ticks?
    private(set) var lastSnapshot: CPUSnapshot = .empty

    func prime() {
        previous = currentTicks()
    }

    func read() -> CPUSnapshot {
        guard let current = currentTicks() else { return snapshotWithCurrentLoad(lastSnapshot) }
        defer { previous = current }
        guard let previous else {
            return snapshotWithCurrentLoad(lastSnapshot)
        }

        let userDelta = delta(current.user, previous.user)
        let systemDelta = delta(current.system, previous.system)
        let idleDelta = delta(current.idle, previous.idle)
        let niceDelta = delta(current.nice, previous.nice)
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return snapshotWithCurrentLoad(lastSnapshot) }

        let userPercent = percent(userDelta + niceDelta, totalDelta)
        let systemPercent = percent(systemDelta, totalDelta)
        let idlePercent = percent(idleDelta, totalDelta)
        let usage = clamp(userPercent + systemPercent)
        let loads = loadAverages()

        let snapshot = CPUSnapshot(
            usage: usage,
            rawUsage: usage,
            userUsage: userPercent,
            systemUsage: systemPercent,
            idleUsage: idlePercent,
            logicalCoreCount: ProcessInfo.processInfo.processorCount,
            loadAverage1Minute: loads.0,
            loadAverage5Minutes: loads.1,
            loadAverage15Minutes: loads.2
        )
        lastSnapshot = snapshot
        return snapshot
    }

    private func currentTicks() -> Ticks? {
        var load = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &load) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return Ticks(
            user: UInt64(load.cpu_ticks.0),
            system: UInt64(load.cpu_ticks.1),
            idle: UInt64(load.cpu_ticks.2),
            nice: UInt64(load.cpu_ticks.3)
        )
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    private func percent(_ part: UInt64, _ total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return clamp(Double(part) / Double(total) * 100)
    }

    private func loadAverages() -> (Double, Double, Double) {
        var values = [Double](repeating: 0, count: 3)
        let count = values.withUnsafeMutableBufferPointer { buffer in
            getloadavg(buffer.baseAddress, 3)
        }
        guard count == 3 else { return (0, 0, 0) }
        return (max(values[0], 0), max(values[1], 0), max(values[2], 0))
    }

    private func snapshotWithCurrentLoad(_ snapshot: CPUSnapshot) -> CPUSnapshot {
        let loads = loadAverages()
        var copy = snapshot
        copy.loadAverage1Minute = loads.0
        copy.loadAverage5Minutes = loads.1
        copy.loadAverage15Minutes = loads.2
        return copy
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
