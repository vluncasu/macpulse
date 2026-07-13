import Darwin
import Foundation
#if canImport(IOKit.ps)
import IOKit.ps
#endif

struct MemoryReader {
    func read() -> MemorySnapshot {
        let total = ProcessInfo.processInfo.physicalMemory
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemorySnapshot(
                usedBytes: 0,
                totalBytes: total,
                wiredBytes: 0,
                compressedBytes: 0,
                cachedBytes: 0,
                pressurePercent: 0
            )
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(statistics.free_count + statistics.speculative_count) * pageSize
        let inactive = UInt64(statistics.inactive_count) * pageSize
        let purgeable = UInt64(statistics.purgeable_count) * pageSize
        let cached = min(total, inactive + purgeable)
        let reclaimable = min(total, free + cached)
        let used = total > reclaimable ? total - reclaimable : 0
        let compressed = UInt64(statistics.compressor_page_count) * pageSize
        let wired = UInt64(statistics.wire_count) * pageSize

        // This is an intentionally documented pressure proxy, not a claim to
        // reproduce Activity Monitor's private pressure algorithm.
        let constrained = min(total, wired + compressed)
        let pressure = total > 0
            ? min(max(Double(constrained) / Double(total) * 100, 0), 100)
            : 0

        return MemorySnapshot(
            usedBytes: used,
            totalBytes: total,
            wiredBytes: wired,
            compressedBytes: compressed,
            cachedBytes: cached,
            pressurePercent: pressure
        )
    }
}

struct PowerReader {
    func read(gpu: GPUSnapshot) -> PowerSnapshot {
        let systemPower = batterySystemPowerWatts()
        if let systemPower {
            return PowerSnapshot(
                totalSystemWatts: systemPower,
                cpuPackageWatts: nil,
                gpuWatts: gpu.powerWatts,
                memoryWatts: nil,
                sourceDescription: "Battery telemetry",
                isEstimated: false
            )
        }

        if let gpuPower = gpu.powerWatts {
            return PowerSnapshot(
                totalSystemWatts: nil,
                cpuPackageWatts: nil,
                gpuWatts: gpuPower,
                memoryWatts: nil,
                sourceDescription: "GPU driver telemetry only",
                isEstimated: false
            )
        }

        return .empty
    }

    private func batterySystemPowerWatts() -> Double? {
        #if canImport(IOKit.ps)
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard (description[kIOPSIsPresentKey as String] as? Bool) != false else { continue }

            let voltage = firstNumber(in: description, keys: ["Voltage", "Voltage (mV)", "Voltage(mV)"])
            let amperage = firstNumber(in: description, keys: ["Amperage", "InstantAmperage", "Current", "Current (mA)"])
            guard let voltageMilliVolts = voltage,
                  let currentMilliAmps = amperage,
                  voltageMilliVolts > 0,
                  currentMilliAmps != 0 else { continue }

            let watts = abs(voltageMilliVolts * currentMilliAmps) / 1_000_000
            if watts >= 0.5, watts <= 250 { return watts }
        }
        #endif
        return nil
    }

    private func firstNumber(in dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let number = value as? NSNumber { return number.doubleValue }
            if let value = value as? Double { return value }
            if let value = value as? Int { return Double(value) }
            if let string = value as? String, let value = Double(string) { return value }
        }
        return nil
    }
}
