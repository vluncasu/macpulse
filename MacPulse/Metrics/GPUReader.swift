import Foundation
import IOKit

enum GPUSelectionMode: String, CaseIterable, Identifiable {
    case automatic
    case highestActivity
    case discretePreferred
    case integratedPreferred

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .highestActivity: return "Highest activity"
        case .discretePreferred: return "Prefer discrete GPU"
        case .integratedPreferred: return "Prefer integrated GPU"
        }
    }
}

struct GPUReadResult {
    var primary: GPUSnapshot
    var devices: [GPUSnapshot]
}

struct GPUReader {
    func read(
        selectionMode: GPUSelectionMode = .automatic,
        previousPrimaryID: String? = nil,
        allowCommandFallback: Bool = true
    ) -> GPUReadResult {
        var snapshots: [GPUSnapshot] = []
        var visitedEntryIDs = Set<UInt64>()

        for serviceClass in ["AGXAccelerator", "IOAccelerator"] {
            snapshots.append(contentsOf: readDirect(
                serviceClass: serviceClass,
                visitedEntryIDs: &visitedEntryIDs
            ))
        }

        #if !MACPULSE_WIDGET
        if allowCommandFallback,
           snapshots.isEmpty || snapshots.allSatisfy({ !$0.isAvailable }) {
            for serviceClass in ["AGXAccelerator", "IOAccelerator"] {
                snapshots.append(contentsOf: readUsingIORegCommand(serviceClass: serviceClass))
            }
        }
        #endif

        let devices = deduplicated(snapshots).sorted(by: deviceOrdering)
        guard let primary = selectPrimary(
            from: devices,
            mode: selectionMode,
            previousPrimaryID: previousPrimaryID
        ) else {
            return GPUReadResult(primary: .unavailable, devices: [])
        }
        return GPUReadResult(primary: primary, devices: devices)
    }

    private func readDirect(
        serviceClass: String,
        visitedEntryIDs: inout Set<UInt64>
    ) -> [GPUSnapshot] {
        guard let matching = IOServiceMatching(serviceClass) else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var snapshots: [GPUSnapshot] = []
        while true {
            let service = IOIteratorNext(iterator)
            guard service != 0 else { break }
            defer { IOObjectRelease(service) }

            var entryID: UInt64 = 0
            let hasEntryID = IORegistryEntryGetRegistryEntryID(service, &entryID) == KERN_SUCCESS
            if hasEntryID, !visitedEntryIDs.insert(entryID).inserted { continue }

            var unmanagedProperties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service,
                &unmanagedProperties,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
            let cfProperties = unmanagedProperties?.takeRetainedValue(),
            let properties = cfProperties as? [String: Any]
            else {
                continue
            }

            if let snapshot = GPUStatisticsParser.parse(
                properties: properties,
                serviceClass: serviceClass,
                registryEntryID: hasEntryID ? entryID : nil
            ) {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }

    #if !MACPULSE_WIDGET
    private func readUsingIORegCommand(serviceClass: String) -> [GPUSnapshot] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-a", "-r", "-d", "2", "-w", "0", "-c", serviceClass]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            return GPUStatisticsParser.parseIORegPropertyList(data, serviceClass: serviceClass)
                .map { value in
                    var copy = value
                    copy.source = .commandFallback
                    return copy
                }
        } catch {
            return []
        }
    }
    #endif

    private func deduplicated(_ snapshots: [GPUSnapshot]) -> [GPUSnapshot] {
        var mergedByID: [String: GPUSnapshot] = [:]
        for snapshot in snapshots {
            if let current = mergedByID[snapshot.id] {
                mergedByID[snapshot.id] = merged(current, snapshot)
            } else {
                mergedByID[snapshot.id] = snapshot
            }
        }
        return Array(mergedByID.values)
    }

    private func merged(_ lhs: GPUSnapshot, _ rhs: GPUSnapshot) -> GPUSnapshot {
        let preferredBase = qualityScore(lhs) >= qualityScore(rhs) ? lhs : rhs
        let other = preferredBase.id == lhs.id && preferredBase.modelName == lhs.modelName && preferredBase.source == lhs.source ? rhs : lhs
        var result = preferredBase

        let mergedUsage = preferredPercentage(preferredBase.rawUsage ?? preferredBase.usage, other.rawUsage ?? other.usage)
        result.rawUsage = mergedUsage
        result.usage = mergedUsage
        result.modelName = result.modelName.count >= other.modelName.count ? result.modelName : other.modelName
        result.vendorName = result.vendorName ?? other.vendorName
        result.temperatureCelsius = preferredNonZero(result.temperatureCelsius, other.temperatureCelsius)
        result.coreClockMHz = preferredNonZero(result.coreClockMHz, other.coreClockMHz)
        result.memoryClockMHz = preferredNonZero(result.memoryClockMHz, other.memoryClockMHz)
        result.fanRPM = preferredNonZero(result.fanRPM, other.fanRPM)
        result.fanPercent = preferredPercentage(result.fanPercent, other.fanPercent)
        result.powerWatts = preferredNonZero(result.powerWatts, other.powerWatts)
        result.activeMemoryBytes = preferredNonZero(result.activeMemoryBytes, other.activeMemoryBytes)
        result.allocatedMemoryBytes = preferredNonZero(result.allocatedMemoryBytes, other.allocatedMemoryBytes)
        result.reclaimableMemoryBytes = preferredNonZero(result.reclaimableMemoryBytes, other.reclaimableMemoryBytes)
        result.freeVRAMBytes = preferredNonZero(result.freeVRAMBytes, other.freeVRAMBytes)
        result.totalVRAMBytes = preferredNonZero(result.totalVRAMBytes, other.totalVRAMBytes)
        result.isStale = preferredBase.isStale && other.isStale
        result.lastSuccessfulSample = maxDate(preferredBase.lastSuccessfulSample, other.lastSuccessfulSample)
        return result
    }

    private func selectPrimary(
        from snapshots: [GPUSnapshot],
        mode: GPUSelectionMode,
        previousPrimaryID: String?
    ) -> GPUSnapshot? {
        snapshots.max { lhs, rhs in
            selectionScore(lhs, mode: mode, previousPrimaryID: previousPrimaryID)
                < selectionScore(rhs, mode: mode, previousPrimaryID: previousPrimaryID)
        }
    }

    private func selectionScore(
        _ snapshot: GPUSnapshot,
        mode: GPUSelectionMode,
        previousPrimaryID: String?
    ) -> Double {
        var score = Double(qualityScore(snapshot))
        let activity = snapshot.rawUsage ?? snapshot.usage ?? 0

        if activity > 0.75 { score += 220 }
        if activity > 0.05 { score += activity * 6 }
        if (snapshot.activeMemoryBytes ?? 0) > 0 { score += 18 }
        if snapshot.powerWatts != nil { score += 14 }
        if snapshot.temperatureCelsius != nil { score += 8 }
        if snapshot.id == previousPrimaryID { score += activity > 0.5 ? 70 : 18 }

        switch mode {
        case .automatic:
            if isDiscrete(snapshot) { score += 10 }
        case .highestActivity:
            score += activity * 12
        case .discretePreferred:
            score += isDiscrete(snapshot) ? 500 : 0
            score += activity * 2
        case .integratedPreferred:
            score += isIntegrated(snapshot) ? 500 : 0
            score += activity * 2
        }
        return score
    }

    private func qualityScore(_ snapshot: GPUSnapshot) -> Int {
        var score = snapshot.usage == nil ? 0 : 1_000
        score += snapshot.detailCount * 15
        if snapshot.source != .commandFallback { score += 30 }
        if snapshot.modelName != snapshot.registryClass { score += 10 }
        if (snapshot.rawUsage ?? snapshot.usage ?? 0) > 0.5 { score += 20 }
        return score
    }

    private func preferredPercentage(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (a?, b?):
            if a > 0.5, b <= 0.5 { return a }
            if b > 0.5, a <= 0.5 { return b }
            return a >= b ? a : b
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    private func preferredNonZero(_ lhs: Double?, _ rhs: Double?) -> Double? {
        switch (lhs, rhs) {
        case let (a?, b?):
            if a > 0, b <= 0 { return a }
            if b > 0, a <= 0 { return b }
            return a >= b ? a : b
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    private func isDiscrete(_ snapshot: GPUSnapshot) -> Bool {
        let name = snapshot.modelName.lowercased()
        return name.contains("radeon") || name.contains("geforce") || name.contains("quadro")
    }

    private func isIntegrated(_ snapshot: GPUSnapshot) -> Bool {
        let name = snapshot.modelName.lowercased()
        return snapshot.source == .appleSiliconIORegistry
            || name.contains("intel")
            || name.contains("iris")
            || name.contains("uhd")
    }

    private func deviceOrdering(_ lhs: GPUSnapshot, _ rhs: GPUSnapshot) -> Bool {
        if lhs.isAvailable != rhs.isAvailable { return lhs.isAvailable }
        return lhs.modelName.localizedStandardCompare(rhs.modelName) == .orderedAscending
    }
}
