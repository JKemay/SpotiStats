import SwiftUI

/// The visual identity: a lo-fi night-city palette (deep purples and indigo-blues).
///
/// Keeping colors in one place (a "design system") means the whole app stays consistent and a
/// restyle is a one-file change. The full animated scene (rain, smoke) comes in a later phase;
/// this is just the color foundation.
enum Theme {

    enum Colors {
        /// Darkest background, near-black violet.
        static let background = Color(hex: 0x0A0518)
        /// Slightly lifted surface for cards/panels.
        static let surface = Color(hex: 0x16092E)
        /// Primary accent — the neon purple used for highlights.
        static let accent = Color(hex: 0xA78BFA)
        /// Secondary accent — a cooler indigo-blue.
        static let accentBlue = Color(hex: 0x6366F1)
        /// Primary text.
        static let textPrimary = Color(hex: 0xF0E6FF)
        /// Muted/secondary text.
        static let textSecondary = Color(hex: 0xA78BFA).opacity(0.55)

        /// The signature background gradient (top-to-bottom night sky).
        static let backgroundGradient = LinearGradient(
            colors: [Color(hex: 0x0A0518), Color(hex: 0x1E1040), Color(hex: 0x0D0620)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 14
        static let pill: CGFloat = 999
    }
}

extension Color {
    /// Convenience initializer from a 0xRRGGBB hex literal.
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
