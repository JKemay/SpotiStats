import SwiftUI

// MARK: - Hex Initialiser

extension Color {
    /// Creates a `Color` from a six-digit hex string.
    ///
    /// Accepts strings with or without a leading `#`:
    /// ```swift
    /// Color(hex: "#1DB954")  // Spotify green
    /// Color(hex: "1DB954")   // same result
    /// ```
    ///
    /// Returns `.clear` for any malformed input.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8)  & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
            a = 1
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8)  & 0xFF) / 255
            a = Double( int        & 0xFF) / 255
        default:
            self = .clear
            return
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Nocturne Brand Palette

extension Color {
    /// The Nocturne app's core colour tokens.
    ///
    /// All tokens are defined here so designers and developers share one
    /// source of truth; callers never hard-code hex strings.
    enum Nocturne {
        // MARK: Backgrounds
        /// Deep night — the primary app background.
        static let backgroundPrimary   = Color(hex: "#0A0E1A")
        /// Slightly lighter surface for cards and sheets.
        static let backgroundSecondary = Color(hex: "#131929")
        /// Elevated surface — modals, bottom sheets.
        static let backgroundElevated  = Color(hex: "#1C2338")

        // MARK: Accents
        /// Spotify green — used for play controls and CTAs.
        static let spotifyGreen        = Color(hex: "#1DB954")
        /// Electric indigo — secondary accent for stats highlights.
        static let accentIndigo        = Color(hex: "#6366F1")
        /// Soft amber — tertiary accent for streak indicators.
        static let accentAmber         = Color(hex: "#F59E0B")

        // MARK: Text
        /// Primary text on dark backgrounds.
        static let textPrimary         = Color(hex: "#F0F4FF")
        /// Secondary labels, subtitles.
        static let textSecondary       = Color(hex: "#8892AA")
        /// Disabled / placeholder text.
        static let textTertiary        = Color(hex: "#4A5568")

        // MARK: Separators & Overlays
        /// Hairline separator between list rows.
        static let separator           = Color(hex: "#1E2740")
        /// 40 % black scrim over blurred backgrounds.
        static let scrimLight          = Color.black.opacity(0.40)
        /// 70 % black scrim for full-screen overlays.
        static let scrimHeavy          = Color.black.opacity(0.70)
    }
}

// MARK: - Luminance Helpers

extension Color {
    /// Approximate relative luminance using the sRGB coefficients.
    ///
    /// The value is in [0, 1] where 0 is black and 1 is white.
    /// Computed from the resolved `UIColor` so it works with
    /// dynamic / adaptive colours.
    var luminance: Double {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        // sRGB linearisation
        func linearise(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearise(r) + 0.7152 * linearise(g) + 0.0722 * linearise(b)
    }

    /// Returns `true` when the colour is perceptually dark (luminance < 0.5).
    ///
    /// Useful for choosing a contrasting foreground colour:
    /// ```swift
    /// Text("Label").foregroundColor(bg.isDark ? .white : .black)
    /// ```
    var isDark: Bool { luminance < 0.5 }
}

// MARK: - Tinting

extension Color {
    /// Returns a lighter version of the colour by blending it with white.
    ///
    /// - Parameter fraction: How much white to blend in (0 = unchanged, 1 = white).
    func lightened(by fraction: Double = 0.15) -> Color {
        blend(with: .white, fraction: fraction)
    }

    /// Returns a darker version of the colour by blending it with black.
    ///
    /// - Parameter fraction: How much black to blend in (0 = unchanged, 1 = black).
    func darkened(by fraction: Double = 0.15) -> Color {
        blend(with: .black, fraction: fraction)
    }

    // MARK: Private Helpers

    private func blend(with other: Color, fraction: Double) -> Color {
        let f = fraction.clamped(to: 0...1)
        let base = UIColor(self)
        let target = UIColor(other)
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        target.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        return Color(
            red:     Double(br + (tr - br) * f),
            green:   Double(bg + (tg - bg) * f),
            blue:    Double(bb + (tb - bb) * f),
            opacity: Double(ba + (ta - ba) * f)
        )
    }
}
