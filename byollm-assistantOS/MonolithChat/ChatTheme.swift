//
//  ChatTheme.swift
//  byollm-assistantOS
//
//  Design tokens for the Monolith Chat app.
//  Single source of truth — palette matches the Local AI mobile app
//  design reference. Light and dark variants resolved via ColorScheme.
//

import SwiftUI

// MARK: - Color(hex:) helper
extension Color {
    /// Creates a Color from a hex string like "#060606" or "060606".
    /// Supports 6-digit RGB and 8-digit ARGB.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - ChatTheme
/// Semantic color tokens. `resolve(_:)` maps the active color scheme to
/// the right palette — mirrors the design's `[data-theme]` CSS variables.
enum ChatTheme {

    enum Mode {
        case light, dark

        static func from(_ scheme: ColorScheme) -> Mode {
            scheme == .dark ? .dark : .light
        }
    }

    /// Page backdrop (behind the app surface).
    static func page(_ m: Mode) -> Color { m == .dark ? Color(hex: "060606") : Color(hex: "EDEDED") }
    /// App background.
    static func bg(_ m: Mode) -> Color { m == .dark ? Color(hex: "0F0E0D") : Color(hex: "FFFFFF") }
    /// Raised surface (cards, composer, search fields).
    static func surface(_ m: Mode) -> Color { m == .dark ? Color(hex: "1B1917") : Color(hex: "F8F8F8") }
    /// Card background.
    static func card(_ m: Mode) -> Color { m == .dark ? Color(hex: "1B1917") : Color(hex: "FFFFFF") }
    /// Hairline border.
    static func line(_ m: Mode) -> Color { m == .dark ? Color(hex: "262320") : Color(hex: "EDEDED") }
    /// Stronger border (input fields, pills).
    static func line2(_ m: Mode) -> Color { m == .dark ? Color(hex: "322E2A") : Color(hex: "E2E0DD") }
    /// Primary text.
    static func text(_ m: Mode) -> Color { m == .dark ? Color(hex: "F8F8F8") : Color(hex: "060606") }
    /// Secondary text.
    static func sub(_ m: Mode) -> Color { m == .dark ? Color(hex: "ABABAB") : Color(hex: "8A8681") }
    /// User message bubble.
    static func bubble(_ m: Mode) -> Color { m == .dark ? Color(hex: "35302C") : Color(hex: "060606") }
    /// User bubble text.
    static func bubbletext(_ m: Mode) -> Color { Color(hex: "FFFFFF") }
    /// Code block background.
    static func codebg(_ m: Mode) -> Color { m == .dark ? Color(hex: "000000") : Color(hex: "060606") }
    /// Code block text.
    static func codetext(_ m: Mode) -> Color { Color(hex: "F8F8F8") }
    /// Scrim behind sheets/drawer.
    static func scrim(_ m: Mode) -> Color { m == .dark ? Color.black.opacity(0.6) : Color(hex: "060606").opacity(0.4) }

    // Status
    static let online = Color(hex: "26B759")
    static let testing = Color(hex: "F39A46")
    static let offline = Color(hex: "FF1B1B")
    static let unknown = Color(hex: "ABABAB")
}

// MARK: - Typography
/// Plus Jakarta Sans when bundled; falls back to system rounded/sans.
enum ChatFont {
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Graceful fallback: system sans at the design's weights.
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
