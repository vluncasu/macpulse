import XCTest

final class MetricSmootherTests: XCTestCase {
    func testFirstSampleIsNotDelayed() {
        var smoother = MetricSmoother()
        let value = smoother.update(rawValue: 42, at: Date(), enabled: true)
        XCTAssertEqual(value, 42, accuracy: 0.001)
    }

    func testOutputRemainsBounded() {
        var smoother = MetricSmoother()
        let start = Date()
        _ = smoother.update(rawValue: 0, at: start, enabled: true)
        let value = smoother.update(rawValue: 250, at: start.addingTimeInterval(1), enabled: true)
        XCTAssertGreaterThanOrEqual(value, 0)
        XCTAssertLessThanOrEqual(value, 100)
    }

    func testCalmReleaseDoesNotDropAbruptly() {
        var smoother = MetricSmoother()
        let start = Date()
        _ = smoother.update(rawValue: 90, at: start, enabled: true)
        let value = smoother.update(
            rawValue: 0,
            at: start.addingTimeInterval(0.2),
            enabled: true,
            attackTime: 0.5,
            releaseTime: 2.0
        )
        XCTAssertGreaterThan(value, 70)
    }

    func testDirectModeReturnsTarget() {
        var smoother = MetricSmoother()
        _ = smoother.update(rawValue: 10, at: Date(), enabled: true)
        let value = smoother.update(rawValue: 84, at: Date().addingTimeInterval(0.1), enabled: false)
        XCTAssertEqual(value, 84, accuracy: 0.001)
    }

    func testAdaptivePolicyBacksOffWhenIdle() {
        let active = AdaptiveSamplingPolicy.loopInterval(
            profile: .balanced,
            dashboardVisible: false,
            idleSamples: 0,
            lowPowerMode: false,
            thermalCondition: .nominal
        )
        let idle = AdaptiveSamplingPolicy.loopInterval(
            profile: .balanced,
            dashboardVisible: false,
            idleSamples: 20,
            lowPowerMode: false,
            thermalCondition: .nominal
        )
        XCTAssertGreaterThan(idle, active)
    }
}
