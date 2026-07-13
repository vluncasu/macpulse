import Foundation

enum GPUStatisticsParser {
    private static let usageKeys = [
        "Device Utilization %",
        "Device Utilization",
        "GPU Activity(%)",
        "GPU Activity %",
        "GPU Utilization %",
        "GPU Utilization",
        "GPU Core Utilization",
        "GPU Core Utilization %",
        "Renderer Utilization",
        "accelBusyPercent",
        "GPU Busy",
        "GPU Busy %"
    ]

    private static let temperatureKeys = [
        "Temperature(C)", "GPU Temperature(C)", "GPU Temperature", "Temperature"
    ]
    private static let coreClockKeys = [
        "Core Clock(MHz)", "GPU Core Clock(MHz)", "GPU Frequency(MHz)", "Core Clock"
    ]
    private static let memoryClockKeys = [
        "Memory Clock(MHz)", "VRAM Clock(MHz)", "Memory Clock"
    ]
    private static let powerKeys = ["Total Power(W)", "GPU Power(W)", "GPU Power"]
    private static let activeMemoryKeys = [
        "In use system memory", "inUseSysMemoryBytes", "inUseVidMemoryBytes"
    ]
    private static let allocatedMemoryKeys = [
        "Alloc system memory", "Allocated system memory", "gartUsedBytes"
    ]
    private static let reclaimableMemoryKeys = [
        "orphanedReusableVidMemoryBytes", "reclaimableMemoryBytes"
    ]
    private static let freeMemoryKeys = ["vramFreeBytes", "VRAM Free Bytes"]
    private static let totalMemoryKeys = ["vramSizeBytes", "VRAM Total Bytes", "VRAM,totalMB"]
    private static let fanRPMKeys = ["Fan Speed(RPM)", "Fan RPM"]
    private static let fanPercentKeys = ["Fan Speed(%)", "Fan Percent"]

    static func parse(
        properties: [String: Any],
        serviceClass: String,
        registryEntryID: UInt64? = nil
    ) -> GPUSnapshot? {
        let dictionaries = candidateDictionaries(in: properties)
        guard !dictionaries.isEmpty else { return nil }

        let model = modelName(from: properties)
            ?? dictionaries.lazy.compactMap(modelName(from:)).first
            ?? serviceClass
        let source: GPUMetricSource = serviceClass.localizedCaseInsensitiveContains("AGX")
            ? .appleSiliconIORegistry
            : .ioAccelerator
        let vendor = vendorName(properties: properties, modelName: model)

        let parsed = dictionaries.compactMap { dictionary -> GPUSnapshot? in
            let usage = normalizedPercentage(firstNumber(for: usageKeys, in: dictionary))
            let temperature = firstNumber(for: temperatureKeys, in: dictionary)
            let activeMemory = firstNumber(for: activeMemoryKeys, in: dictionary)
            let hasUsefulTelemetry = usage != nil || temperature != nil || activeMemory != nil
            guard hasUsefulTelemetry else { return nil }

            return GPUSnapshot(
                id: stableIdentifier(
                    registryEntryID: registryEntryID,
                    serviceClass: serviceClass,
                    modelName: model
                ),
                usage: usage,
                rawUsage: usage,
                modelName: cleanModelName(model),
                vendorName: vendor,
                registryClass: serviceClass,
                source: source,
                temperatureCelsius: plausibleTemperature(temperature),
                coreClockMHz: plausibleNonNegative(firstNumber(for: coreClockKeys, in: dictionary)),
                memoryClockMHz: plausibleNonNegative(firstNumber(for: memoryClockKeys, in: dictionary)),
                fanRPM: plausibleNonNegative(firstNumber(for: fanRPMKeys, in: dictionary)),
                fanPercent: normalizedPercentage(firstNumber(for: fanPercentKeys, in: dictionary)),
                powerWatts: plausibleNonNegative(firstNumber(for: powerKeys, in: dictionary)),
                activeMemoryBytes: plausibleNonNegative(activeMemory),
                allocatedMemoryBytes: plausibleNonNegative(firstNumber(for: allocatedMemoryKeys, in: dictionary)),
                reclaimableMemoryBytes: plausibleNonNegative(firstNumber(for: reclaimableMemoryKeys, in: dictionary)),
                freeVRAMBytes: plausibleNonNegative(firstNumber(for: freeMemoryKeys, in: dictionary)),
                totalVRAMBytes: normalizedTotalMemory(firstNumber(for: totalMemoryKeys, in: dictionary)),
                isStale: false,
                lastSuccessfulSample: .now
            )
        }

        return parsed.max { score($0) < score($1) }
    }

    static func parseIORegPropertyList(_ data: Data, serviceClass: String) -> [GPUSnapshot] {
        guard let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return []
        }

        let serviceDictionaries: [[String: Any]]
        if let array = root as? [Any] {
            serviceDictionaries = array.compactMap(bridgeDictionary)
        } else if let dictionary = bridgeDictionary(root) {
            serviceDictionaries = [dictionary]
        } else {
            serviceDictionaries = []
        }

        return serviceDictionaries.enumerated().compactMap { index, properties in
            guard var snapshot = parse(properties: properties, serviceClass: serviceClass) else { return nil }
            if snapshot.id.contains(":fallback") {
                snapshot.id += ":\(index)"
            }
            return snapshot
        }
    }

    private static func score(_ snapshot: GPUSnapshot) -> Int {
        var value = snapshot.usage == nil ? 0 : 1_000
        value += snapshot.detailCount * 12
        if snapshot.modelName != snapshot.registryClass { value += 15 }
        if snapshot.source == .appleSiliconIORegistry { value += 5 }
        return value
    }

    private static func candidateDictionaries(in properties: [String: Any]) -> [[String: Any]] {
        var results: [[String: Any]] = []

        func walk(_ value: Any, depth: Int) {
            guard depth < 8 else { return }
            if let dictionary = bridgeDictionary(value) {
                let keys = Set(dictionary.keys)
                let telemetryKeys = usageKeys + temperatureKeys + activeMemoryKeys + powerKeys
                if telemetryKeys.contains(where: keys.contains) {
                    results.append(dictionary)
                }
                for nested in dictionary.values { walk(nested, depth: depth + 1) }
            } else if let array = value as? [Any] {
                for nested in array { walk(nested, depth: depth + 1) }
            } else if let array = value as? NSArray {
                for nested in array { walk(nested, depth: depth + 1) }
            }
        }

        walk(properties, depth: 0)
        return results
    }

    private static func bridgeDictionary(_ value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] { return dictionary }
        guard let dictionary = value as? NSDictionary else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dictionary {
            if let key = key as? String { result[key] = value }
        }
        return result
    }

    private static func firstNumber(for keys: [String], in dictionary: [String: Any]) -> Double? {
        for key in keys {
            if let value = number(for: key, in: dictionary) { return value }
        }
        return nil
    }

    private static func number(for key: String, in dictionary: [String: Any]) -> Double? {
        guard let value = dictionary[key] else { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? UInt64 { return Double(value) }
        if let value = value as? UInt32 { return Double(value) }
        if let string = value as? String {
            let normalized = string
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let numericPrefix = normalized.prefix { $0.isNumber || $0 == "." || $0 == "-" }
            return Double(numericPrefix)
        }
        return nil
    }

    private static func normalizedPercentage(_ value: Double?) -> Double? {
        guard var value, value.isFinite else { return nil }
        if value > 0, value <= 1 { value *= 100 }
        return min(max(value, 0), 100)
    }

    private static func plausibleTemperature(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= -20, value <= 150 else { return nil }
        return value
    }

    private static func plausibleNonNegative(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func normalizedTotalMemory(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        // Some drivers publish total VRAM in MiB despite the key naming. Values
        // below 64 MiB are treated as a count in MiB and converted to bytes.
        if value < 65_536 { return value * 1_048_576 }
        return value
    }

    private static func modelName(from dictionary: [String: Any]) -> String? {
        let keys = ["model", "Model", "GPU Name", "MetalPluginName", "IOClass", "CFBundleIdentifier"]
        for key in keys {
            guard let value = dictionary[key] else { continue }
            if let string = value as? String, !string.isEmpty { return string }
            if let data = value as? Data {
                let bytes = [UInt8](data)
                let terminated = bytes.prefix { $0 != 0 }
                if let string = String(bytes: terminated, encoding: .utf8), !string.isEmpty {
                    return string
                }
            }
        }
        return nil
    }

    private static func cleanModelName(_ model: String) -> String {
        model.replacingOccurrences(of: "\0", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func vendorName(properties: [String: Any], modelName: String) -> String? {
        let lower = modelName.lowercased()
        if lower.contains("apple") || lower.contains("agx") { return "Apple" }
        if lower.contains("amd") || lower.contains("radeon") { return "AMD" }
        if lower.contains("intel") || lower.contains("iris") || lower.contains("uhd") { return "Intel" }
        if lower.contains("nvidia") || lower.contains("geforce") || lower.contains("quadro") { return "NVIDIA" }

        for key in ["vendor", "Vendor", "vendor-id"] {
            if let value = properties[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }

    private static func stableIdentifier(
        registryEntryID: UInt64?,
        serviceClass: String,
        modelName: String
    ) -> String {
        if let registryEntryID { return "\(serviceClass):\(registryEntryID)" }
        let safeModel = cleanModelName(modelName)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(serviceClass):fallback:\(safeModel)"
    }
}
