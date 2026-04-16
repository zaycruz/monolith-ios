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
        static let stateWarning = Color(hex: "#FBBF24")

        // Human avatar palette (base hues, paired with lighter shades for gradient fills)
        static let humanZayBlue      = Color(hex: "#3B5BDB")
        static let humanZayBlueTop   = Color(hex: "#5C7CFA")
        static let humanSofiaViolet  = Color(hex: "#7048E8")
        static let humanSofiaTop     = Color(hex: "#9775FA")
        static let humanJasonCyan    = Color(hex: "#0EA5E9")
        static let humanJasonTop     = Color(hex: "#38BDF8")
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

        // Accents (reserved for the whisper footer gradient only)
        static let accent        = Palette.accentBlue
        static let accentAlt     = Palette.accentViolet
        static let whisper       = Palette.accentTeal

        // State
        static let statusRunning = Palette.stateRunning
        static let statusIdle    = Palette.stateIdle
        static let statusError   = Palette.stateError
        static let statusWarning = Palette.stateWarning
    }

    // MARK: Glass surfaces
    /// Liquid-glass overlay tokens. In SwiftUI these are paired with
    /// `.background(.ultraThinMaterial)` / `.regularMaterial` to create
    /// the translucent, saturated blur effect specified in v0.3.
    enum Glass {
        /// Translucent fill laid over a material to keep the surface dark.
        static let bg           = Color(white: 22.0 / 255.0).opacity(0.55)
        /// Default glass border — subtle, trending almost invisible over void.
        static let border       = Color.white.opacity(0.06)
        /// Even softer border variant for search bars / secondary glass pills.
        static let borderSubtle = Color.white.opacity(0.04)
        /// Inner highlight applied as a top-edge inset stroke / box-shadow.
        static let highlight    = Color.white.opacity(0.03)
        /// Hover fill for rows.
        static let hover        = Color.white.opacity(0.015)
        /// Active row / selected state fill.
        static let active       = Color.white.opacity(0.06)
        /// Tool-call card inner fill (layered over material).
        static let toolCardFill = Color(white: 8.0 / 255.0).opacity(0.7)
        /// Inner field fill used inside the composer.
        static let inputFill    = Color(white: 22.0 / 255.0).opacity(0.7)
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
    /// v0.3 radius scale. Kept compatible with the v0.2 names via
    /// explicit values — call sites use `.md` / `.lg` / `.xl` / `.pill`.
    enum Radius {
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 14   // search bars, rows, composer inner
        static let lg:   CGFloat = 16   // template cards
        static let xl:   CGFloat = 20   // reactions, rounded pills
        static let pill: CGFloat = 9999
    }

    // MARK: Avatar size variants
    enum AvatarSize {
        /// 20pt — used in member stacks and mention chips.
        case xs
        /// 20pt — thread participant stacks (kept as a name alias).
        case sm
        /// 28pt — dense list rows.
        case md
        /// 36pt — channel / DM / message rows.
        case lg
        /// 44pt — larger accent row (inline reply avatars, agent DM header).
        case xl
        /// 56pt — agent detail hero.
        case xxl

        var dimension: CGFloat {
            switch self {
            case .xs:  return 20
            case .sm:  return 20
            case .md:  return 28
            case .lg:  return 36
            case .xl:  return 44
            case .xxl: return 56
            }
        }

        /// Corner radius for agent (square-ish) avatars — 22% of dimension.
        var agentCornerRadius: CGFloat { dimension * 0.22 }

        /// Width of the agent "slit" — the brand mark on the left edge.
        var slitWidth: CGFloat {
            switch self {
            case .xs, .sm: return 1.5
            case .md:      return 2
            case .lg:      return 2
            case .xl:      return 2.5
            case .xxl:     return 3
            }
        }

        /// Font size for initials inside the avatar.
        var initialFontSize: CGFloat {
            switch self {
            case .xs, .sm: return 9
            case .md:      return 11
            case .lg:      return 13
            case .xl:      return 15
            case .xxl:     return 20
            }
        }

        /// Diameter of the presence dot overlaid on the avatar.
        var presenceDotSize: CGFloat {
            switch self {
            case .xs, .sm: return 7
            case .md:      return 9
            case .lg:      return 12
            case .xl:      return 13
            case .xxl:     return 16
            }
        }
    }
}

// MARK: - Status color helper
extension Color {
    /// Apply the green running-dot glow used across presence indicators.
    func glow(radius: CGFloat = 4, opacity: Double = 0.5) -> some View {
        Circle()
            .fill(self)
            .shadow(color: self.opacity(opacity), radius: radius)
    }
}

// MARK: - Typography
/// MonolithFont — helper that returns the right Font with graceful fallback
/// when JetBrains Mono / IBM Plex Sans are not bundled.
///
/// v0.3 policy: IBM Plex Sans is the primary UI font. JetBrains Mono is
/// reserved for agent identities, tool-call content, runtime data (VM
/// specs, uptime, region, model name, token counts), inline `code`, and
/// the lowercase `agent` tag next to agent authors.
enum MonolithFont {

    // Mono weights used for agent names, tool calls, metadata, timestamps.
    static func mono(size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "JetBrainsMono-Regular"
        case .medium:   name = "JetBrainsMono-Medium"
        case .semibold: name = "JetBrainsMono-SemiBold"
        case .bold:     name = "JetBrainsMono-Bold"
        }
        // Graceful fallback: system monospaced if custom font is not bundled.
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return Font.system(size: size, weight: weight.systemWeight, design: .monospaced)
    }

    // Sans for human names, body copy, channels, section headers — almost everything.
    static func sans(size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .regular:  name = "IBMPlexSans-Regular"
        case .medium:   name = "IBMPlexSans-Medium"
        case .semibold: name = "IBMPlexSans-SemiBold"
        case .bold:     name = "IBMPlexSans-Bold"
        }
        #if canImport(UIKit)
        if UIFont(name: name, size: size) != nil {
            return Font.custom(name, size: size)
        }
        #endif
        return Font.system(size: size, weight: weight.systemWeight, design: .default)
    }

    enum Weight {
        case regular, medium, semibold, bold

        var systemWeight: Font.Weight {
            switch self {
            case .regular:  return .regular
            case .medium:   return .medium
            case .semibold: return .semibold
            case .bold:     return .bold
            }
        }
    }
}
