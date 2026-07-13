import Foundation

struct MetricSmoother {
    private(set) var value: Double?
    private var timestamp: Date?

    mutating func reset() {
        value = nil
        timestamp = nil
    }

    /// A time-domain exponential smoother with asymmetric attack/release and
    /// a rate limiter. Fast increases remain visible while decreases settle
    /// gently, preventing distracting oscillation in a persistent UI.
    mutating func update(
        rawValue: Double,
        at date: Date,
        enabled: Bool,
        attackTime: TimeInterval = 0.55,
        releaseTime: TimeInterval = 1.35,
        maximumRiseRate: Double = 85,
        maximumFallRate: Double = 48
    ) -> Double {
        let target = min(max(rawValue, 0), 100)
        guard enabled, let previousValue = value, let previousDate = timestamp else {
            value = target
            timestamp = date
            return target
        }

        let deltaTime = min(max(date.timeIntervalSince(previousDate), 0.02), 10)
        let responseTime = target >= previousValue ? attackTime : releaseTime
        let alpha = 1 - exp(-deltaTime / max(responseTime, 0.02))
        let filtered = previousValue + (target - previousValue) * alpha
        let rise = maximumRiseRate * deltaTime
        let fall = maximumFallRate * deltaTime
        let limited = min(max(filtered, previousValue - fall), previousValue + rise)
        let result = min(max(limited, 0), 100)

        value = result
        timestamp = date
        return result
    }
}
