import SwiftUI

/// A small 8-point sparkle/asterisk mark, drawn as an original vector shape in a
/// warm orange — stands in for "built with AI help" next to the heart emoji.
/// This is NOT Anthropic's trademarked Claude logo asset (no rights to redistribute
/// that file); it's an original rendering in the same spirit.
struct SparkleMark: View {
    var size: CGFloat = 14
    var color: Color = Color(red: 0.82, green: 0.47, blue: 0.34)

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let outerRadius = min(canvasSize.width, canvasSize.height) / 2
            let innerRadius = outerRadius * 0.34
            let points = 8
            var path = Path()
            for i in 0..<(points * 2) {
                let angle = (Double(i) / Double(points * 2)) * 2 * .pi - .pi / 2
                let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            context.fill(path, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}
