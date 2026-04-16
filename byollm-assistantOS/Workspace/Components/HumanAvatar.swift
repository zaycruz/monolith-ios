//
//  HumanAvatar.swift
//  Workspace
//
//  Circle avatar with a top-left to bottom-right gradient fill. The
//  shape-contrast with AgentAvatar is deliberate — agents are rounded
//  squares with slits, humans are filled circles. v0.3 added the
//  gradient depth (was flat solid in v0.2).
//

import SwiftUI

struct HumanAvatar: View {
    let human: Human
    let size: MonolithTheme.AvatarSize

    init(human: Human, size: MonolithTheme.AvatarSize = .lg) {
        self.human = human
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [topColor, baseColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(human.initials)
                    .font(MonolithFont.sans(size: size.initialFontSize, weight: .semibold))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
            )
            .frame(width: size.dimension, height: size.dimension)
            .accessibilityLabel("Human \(human.displayName)")
    }

    private var baseColor: Color {
        Color(hex: human.colorHex)
    }

    /// Top-left gradient color. Falls back to the base color lightened by
    /// ~15% when the human has no explicit `gradientTopHex`.
    private var topColor: Color {
        if let top = human.gradientTopHex {
            return Color(hex: top)
        }
        return Self.lightened(hex: human.colorHex, by: 0.18)
    }

    /// Lighten a hex color by mixing with white. Pure math so it doesn't
    /// need UIKit — keeps preview-safe.
    private static func lightened(hex: String, by amount: Double) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        let t = max(0, min(1, amount))
        return Color(
            .sRGB,
            red: r + (1 - r) * t,
            green: g + (1 - g) * t,
            blue: b + (1 - b) * t,
            opacity: 1
        )
    }
}

#Preview("Human avatar sizes") {
    HStack(spacing: 12) {
        HumanAvatar(human: MockHumans.zay, size: .xs)
        HumanAvatar(human: MockHumans.zay, size: .md)
        HumanAvatar(human: MockHumans.zay, size: .lg)
        HumanAvatar(human: MockHumans.sofia, size: .xl)
        HumanAvatar(human: MockHumans.jason, size: .xxl)
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
