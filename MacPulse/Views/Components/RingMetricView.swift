import SwiftUI

struct RingMetricView: View {
    let title: String
    let value: Double?
    let subtitle: String
    let tint: Color
    var diameter: CGFloat = 132

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var normalizedValue: Double {
        min(max((value ?? 0) / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.075), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.7), tint],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.16), radius: 6, y: 2)

                Circle()
                    .fill(.primary.opacity(0.025))
                    .padding(18)

                VStack(spacing: 1) {
                    Text(value.map { "\(Int($0.rounded()))" } ?? "—")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransitionIfAvailable()
                    Text(value == nil ? "unavailable" : "%")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: diameter, height: diameter)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.65), value: normalizedValue)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(value.map { "\(Int($0.rounded())) percent" } ?? "Unavailable")

            VStack(spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: diameter + 30)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func contentTransitionIfAvailable() -> some View {
        if #available(macOS 14.0, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }
}
