import SwiftUI

/// Icon-only button style for the project rows: no bordered chrome, a fixed compact hit area
/// (so the glyph stays clickable despite the small size), and minimal horizontal padding —
/// a row can carry up to five controls and must stay on one line in a 380pt panel.
/// Deliberately NOT accent-coloured: the glyphs use the same primary label colour as the
/// project titles (in dark mode `.secondary` reads as *dimmer*, not lighter) and dim while
/// pressed for click feedback.
struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .frame(width: 20, height: 18)
            .contentShape(Rectangle())
            .foregroundStyle(configuration.isPressed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }
}
