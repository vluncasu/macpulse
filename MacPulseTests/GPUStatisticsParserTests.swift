import XCTest

final class GPUStatisticsParserTests: XCTestCase {
    func testParsesAMDPerformanceStatistics() {
        let properties: [String: Any] = [
            "model": "AMD Radeon Pro 460",
            "PerformanceStatistics": [
                "Device Utilization %": 7,
                "GPU Activity(%)": 0,
                "Temperature(C)": 59,
                "Core Clock(MHz)": 8,
                "Memory Clock(MHz)": 1742,
                "Fan Speed(RPM)": 1199,
                "Total Power(W)": 35,
                "inUseVidMemoryBytes": 5_090_840_576 as NSNumber,
                "vramFreeBytes": 125_378_560 as NSNumber,
                "orphanedReusableVidMemoryBytes": 3_354_898_432 as NSNumber
            ]
        ]

        let snapshot = GPUStatisticsParser.parse(
            properties: properties,
            serviceClass: "IOAccelerator",
            registryEntryID: 42
        )
        XCTAssertEqual(snapshot?.usage, 7)
        XCTAssertEqual(snapshot?.temperatureCelsius, 59)
        XCTAssertEqual(snapshot?.memoryClockMHz, 1742)
        XCTAssertEqual(snapshot?.reclaimableMemoryBytes, 3_354_898_432)
        XCTAssertEqual(snapshot?.source, .ioAccelerator)
        XCTAssertEqual(snapshot?.id, "IOAccelerator:42")
    }

    func testParsesAppleSiliconMemoryKeys() {
        let properties: [String: Any] = [
            "IOClass": "AGXAccelerator",
            "PerformanceStatistics": [
                "Device Utilization %": 31,
                "In use system memory": 1_200_000_000 as NSNumber,
                "Alloc system memory": 2_400_000_000 as NSNumber
            ]
        ]

        let snapshot = GPUStatisticsParser.parse(
            properties: properties,
            serviceClass: "AGXAccelerator"
        )
        XCTAssertEqual(snapshot?.usage, 31)
        XCTAssertEqual(snapshot?.activeMemoryBytes, 1_200_000_000)
        XCTAssertEqual(snapshot?.allocatedMemoryBytes, 2_400_000_000)
        XCTAssertEqual(snapshot?.source, .appleSiliconIORegistry)
    }

    func testNormalizesFractionalUtilization() {
        let properties: [String: Any] = [
            "PerformanceStatistics": ["Renderer Utilization": 0.42]
        ]
        let snapshot = GPUStatisticsParser.parse(
            properties: properties,
            serviceClass: "AGXAccelerator"
        )
        XCTAssertEqual(snapshot?.usage ?? -1, 42, accuracy: 0.001)
    }

    func testRejectsImplausibleTemperature() {
        let properties: [String: Any] = [
            "PerformanceStatistics": [
                "Device Utilization %": 20,
                "Temperature(C)": 65_535
            ]
        ]
        let snapshot = GPUStatisticsParser.parse(
            properties: properties,
            serviceClass: "IOAccelerator"
        )
        XCTAssertNil(snapshot?.temperatureCelsius)
    }
}
