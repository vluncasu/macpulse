import Darwin
import Foundation

struct MachineReader {
    func read() -> MachineSnapshot {
        let model = sysctlString("hw.model") ?? "Unknown Mac"
        return MachineSnapshot(
            hardwareModel: model,
            processorName: sysctlString("machdep.cpu.brand_string") ?? fallbackProcessorName,
            architecture: architecture,
            operatingSystem: "macOS",
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            activeProcessorCount: ProcessInfo.processInfo.activeProcessorCount,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            compatibilityClass: compatibilityClass(model: model)
        )
    }

    private var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private var fallbackProcessorName: String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel-compatible processor"
        #endif
    }

    private func compatibilityClass(model: String) -> String {
        #if arch(arm64)
        return "Apple Silicon Mac"
        #elseif arch(x86_64)
        let knownPrefixes = ["MacBook", "Macmini", "MacPro", "iMac", "MacStudio"]
        return knownPrefixes.contains(where: model.hasPrefix)
            ? "Intel Mac"
            : "Intel-compatible macOS system"
        #else
        return "macOS system"
        #endif
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        let result = buffer.withUnsafeMutableBytes { rawBuffer in
            sysctlbyname(name, rawBuffer.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        return buffer.withUnsafeBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return nil }
            return String(cString: baseAddress)
        }
    }
}
