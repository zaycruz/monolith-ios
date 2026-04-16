//
//  HumanAvatar.swift
//  Workspace
//
//  Circle, color-coded. The shape-contrast with AgentAvatar is deliberate.
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
            .fill(Color(hex: human.colorHex))
            .overlay(
                Text(human.initials)
                    .font(MonolithFont.sans(size: size.initialFontSize, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
            )
            .frame(width: size.dimension, height: size.dimension)
            .accessibilityLabel("Human \(human.displayName)")
    }
}

#Preview("Human avatar sizes") {
    HStack(spacing: 12) {
        HumanAvatar(human: MockHumans.zay, size: .xs)
        HumanAvatar(human: MockHumans.zay, size: .sm)
        HumanAvatar(human: MockHumans.zay, size: .md)
        HumanAvatar(human: MockHumans.zay, size: .lg)
        HumanAvatar(human: MockHumans.sofia, size: .xxl)
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
