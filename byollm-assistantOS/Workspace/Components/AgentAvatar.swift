//
//  AgentAvatar.swift
//  Workspace
//
//  Rounded square + left vertical "slit". The slit is the brand mark —
//  it's what makes an agent visually distinct from a human at a glance.
//

import SwiftUI

struct AgentAvatar: View {
    let agent: Agent
    let size: MonolithTheme.AvatarSize

    init(agent: Agent, size: MonolithTheme.AvatarSize = .lg) {
        self.agent = agent
        self.size = size
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: size.agentCornerRadius)
                .fill(MonolithTheme.Colors.bgPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: size.agentCornerRadius)
                        .stroke(MonolithTheme.Colors.borderStrong, lineWidth: 0.5)
                )

            // The slit — the brand mark.
            Rectangle()
                .fill(slitColor)
                .frame(width: size.slitWidth)
                .clipShape(
                    RoundedRectangle(cornerRadius: size.agentCornerRadius)
                )

            // Initials.
            Text(agent.initials)
                .font(MonolithFont.mono(size: size.initialFontSize, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                // Nudge so initials look centered despite the slit on the left.
                .padding(.leading, size.slitWidth)
        }
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityLabel("Agent \(agent.handle)")
    }

    private var slitColor: Color {
        switch agent.status {
        case .running: return MonolithTheme.Colors.statusRunning
        case .idle:    return MonolithTheme.Colors.statusIdle
        case .error:   return MonolithTheme.Colors.statusError
        }
    }
}

#Preview("Agent avatar sizes") {
    HStack(spacing: 12) {
        AgentAvatar(agent: MockAgents.dispatch, size: .xs)
        AgentAvatar(agent: MockAgents.dispatch, size: .sm)
        AgentAvatar(agent: MockAgents.dispatch, size: .md)
        AgentAvatar(agent: MockAgents.dispatch, size: .lg)
        AgentAvatar(agent: MockAgents.dispatch, size: .xxl)
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
