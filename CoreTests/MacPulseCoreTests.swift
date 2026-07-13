import XCTest
@testable import MacPulseCore

final class MacPulseCoreTests: XCTestCase {
    func testAMDParserUsesDeviceUtilizationAndCapturesCache() {
        let properties: [String: Any] = [
            "model": "AMD Radeon Pro 460",
            "PerformanceStatistics": [
                "Device Utilization %": 7,
                "GPU Activity(%)": 0,
                "Temperature(C)": 59,
                "orphanedReusableVidMemoryBytes": 3_354_898_432 as NSNumber
            ]
        ]
        let result = GPUStatisticsParser.parse(
            properties: properties,
            serviceClass: "IOAccelerator",
            registryEntryID: 5
        )
        XCTAssertEqual(result?.usage, 7)
        XCTAssertEqual(result?.temperatureCelsius, 59)
        XCTAssertEqual(result?.reclaimableMemoryBytes, 3_354_898_432)
    }

    func testFractionalUtilizationIsNormalized() {
        let properties: [String: Any] = [
            "PerformanceStatistics": ["Renderer Utilization": 0.5]
        ]
        let result = GPUStatisticsParser.parse(
            properties: properties,
            serviceClass: "AGXAccelerator"
        )
        XCTAssertEqual(result?.usage ?? -1, 50, accuracy: 0.001)
    }

    func testSmootherIsBounded() {
        var smoother = MetricSmoother()
        let start = Date()
        _ = smoother.update(rawValue: 0, at: start, enabled: true)
        let value = smoother.update(rawValue: 500, at: start.addingTimeInterval(1), enabled: true)
        XCTAssertTrue((0...100).contains(value))
    }

    func testAdaptivePolicyProtectsLowPowerAndThermalStates() {
        let normal = AdaptiveSamplingPolicy.loopInterval(
            profile: .balanced,
            dashboardVisible: false,
            idleSamples: 0,
            lowPowerMode: false,
            thermalCondition: .nominal
        )
        let lowPower = AdaptiveSamplingPolicy.loopInterval(
            profile: .balanced,
            dashboardVisible: false,
            idleSamples: 0,
            lowPowerMode: true,
            thermalCondition: .nominal
        )
        let critical = AdaptiveSamplingPolicy.loopInterval(
            profile: .responsive,
            dashboardVisible: false,
            idleSamples: 0,
            lowPowerMode: false,
            thermalCondition: .critical
        )

        XCTAssertGreaterThan(lowPower, normal)
        XCTAssertGreaterThan(critical, lowPower)
        XCTAssertGreaterThan(
            AdaptiveSamplingPolicy.gpuInterval(
                profile: .balanced,
                dashboardVisible: false,
                idleSamples: 20,
                lowPowerMode: false,
                thermalCondition: .nominal
            ),
            AdaptiveSamplingPolicy.loopInterval(
                profile: .balanced,
                dashboardVisible: false,
                idleSamples: 20,
                lowPowerMode: false,
                thermalCondition: .nominal
            )
        )
    }

}
