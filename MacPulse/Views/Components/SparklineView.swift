import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let tint: Color
    var lineWidth: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, size.width > 0, size.height > 0 else { return }
            let horizontalStep = size.width / CGFloat(values.count - 1)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: CGFloat(index) * horizontalStep,
                    y: size.height - CGFloat(min(max(value / 100, 0), 1)) * size.height
                )
            }

            var fill = Path()
            fill.move(to: CGPoint(x: 0, y: size.height))
            points.enumerated().forEach { index, point in
                index == 0 ? fill.move(to: point) : fill.addLine(to: point)
            }
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [tint.opacity(0.18), tint.opacity(0.01)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            var line = Path()
            for (index, point) in points.enumerated() {
                index == 0 ? line.move(to: point) : line.addLine(to: point)
            }
            context.stroke(
                line,
                with: .color(tint),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
