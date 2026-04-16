//
//  MonolithTheme.swift
//  Workspace
//
//  Design tokens for the Monolith workspace UI.
//  Single source of truth for palette, typography, spacing, radii.
//  Palette names come from design/mockups-v0.3.html; semantic aliases
//  are defined below and should be used at call sites.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color(hex:) helper
// Single source — do not re-declare this extension elsewhere in the Workspace module.
extension Color {
    /// Creates a Color from a hex string like "#1C1F22" or "1C1F22".
    /// Supports 6-digit RGB and 8-digit ARGB.
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            a = Double((value & 0xFF000000) >> 24) / 255.0
            r = Double((value & 0x00FF0000) >> 16) / 255.0
            g = Double((value & 0x0000FF00) >> 8) / 255.0
            b = Double(value & 0x000000FF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - MonolithTheme
enum MonolithTheme {

    // MARK: Palette (raw)
    enum Palette {
        static let void     = Color(hex: "#08090A")
        static let obsidian = Color(hex: "#0F1011")
        static let stone    = Color(hex: "#16181A")
        static let slate    = Color(hex: "#1C1F22")
        static let graphite = Color(hex: "#262A2E")
        static let iron     = Color(hex: "#3A3F44")
        static let ash      = Color(hex: "#6B7075")
        static let fog      = Color(hex: "#9CA1A6")
        static let mist     = Color(hex: "#C8CCD0")
        static let snow     = Color(hex: "#F2F3F4")

        static let accentBlue   = Color(hex: "#224AE8")
        static let accentViolet = Color(hex: "#716EFF")
        static let accentTeal   = Color(hex: "#00BDB7") // gradient bar / whisper only

        static let stateRunning = Color(hex: "#4ADE80")
        static let stateIdle    = Color(hex: "#6B7075")
        static let stateError   = Color(hex: "#F87171")

        // Human avatar palette
        static let humanZayBlue      = Color(hex: "#3B5BDB")
        static let humanSofiaViolet  = Color(hex: "#7048E8")
        static let humanJasonCyan    = Color(hex: "#0EA5E9")
    }

    // MARK: Semantic color aliases
    enum Colors {
        // Backgrounds
        static let bgBase      = Palette.void
        static let bgSurface   = Palette.obsidian
        static let bgElevated  = Palette.stone
        static let bgPanel     = Palette.slate
        static let bgHover     = Palette.graphite

        // Borders / dividers
        static let borderSoft   = Palette.graphite
        static let borderStrong = Palette.iron

        // Text
        static let textPrimary   = Palette.snow
        static let textSecondary = Palette.mist
        static let textTertiary  = Palette.fog
        static let textMuted     = Palette.ash

        // Accents
        static let accent        = Palette.accentBlue
        static let accentAlt     = Palette.accentViolet
        static let whisper       = Palette.accentTeal

        // State
        static let statusRunning = Palette.stateRunning
        static let statusIdle    = Palette.stateIdle
        static let statusError   = Palette.stateError
    }

    // MARK: Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: Radius
    enum Radius {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let pill: CGFloat = 999
    }

    // MARK: Avatar size variants
    enum AvatarSize {
        case xs, sm, md, lg, xxl

        var dimension: CGFloat {
            switch self {
            case .xs:  return 16
            case .sm:  return 20
            case .md:  return 24
            case .lg:  return 32
            case .xxl: return 56
            }
        }

        /// Corner radius for agent (square-ish) avatars, scales with size.
        var agentCornerRadius: CGFloat {
            switch self {
            case .xs:  return 2
            case .sm:  return 3
            case .md:  return 4
            case .lg:  return 5
            case .xxl: return 8
            }
        }

        /// Width of the agent "slit" — the brand mark on the left edge.
        var slitWidth: CGFloat {
            switch self {
            case .xs:  return 1
            case .sm:  return 1.5
            case .md:  return 2
            case .lg:  return 2.5
            case .xxl: return 3
            }
        }

        /// Font size for initials inside the avatar.
        var initialFontSize: CGFloat {
            switch self {
            case .xs:  return 8
            case .sm:  return 10
            case .md:  return 11
            case .lg:  return 13
            case .xxl: return 20
            }
        }
    }
}

// MARK: - Typography
/// MonolithFont — helper that returns the right Font with graceful fallback
/// when JetBrains Mono / IBM Plex Sans are not bundled.
enum MonolithFont {

    // Mono weights used for agent names, tool calls, metadata, timestamps.
    static func mono(size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .regular: name = "JetBrainsMono-Regular"
        case .medium:  name = "JetBrainsMono-Medium"
        case .bold:    name = "JetBrainsMono-Bold"
        }
        // Graceful fallback: system monospaced if custom font is not bundled.
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return Font.system(size: size, weight: weight.systemWeight, design: .monospaced)
    }

    // Sans for human names, body copy.
    static func sans(size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .regular: name = "IBMPlexSans-Regular"
        case .medium:  name = "IBMPlexSans-Medium"
        case .bold:    name = "IBMPlexSans-Bold"
        }
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return Font.system(size: size, weight: weight.systemWeight, design: .default)
    }

    enum Weight {
        case regular, medium, bold

        var systemWeight: Font.Weight {
            switch self {
            case .regular: return .regular
            case .medium:  return .medium
            case .bold:    return .bold
            }
        }
    }
}
