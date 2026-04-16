//
//  AgentAvatar.swift
//  Workspace
//
//  Rounded square (22% corner radius) + left vertical "slit". The slit is
//  the brand mark — it's what makes an agent visually distinct from a
//  human at a glance. v0.3 sizes: 20 / 28 / 36 / 44 / 56.
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
        let dim = size.dimension
        let radius = size.agentCornerRadius

        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: radius)
                .fill(MonolithTheme.Colors.bgPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(MonolithTheme.Colors.borderStrong, lineWidth: 0.5)
                )

            // Slit positioned per v0.3 spec: left 22%, top/bottom 22%, opacity 0.7.
            Rectangle()
                .fill(slitColor)
                .frame(width: size.slitWidth, height: dim * 0.56)
                .opacity(0.7)
                .offset(x: dim * 0.22)

            // Initials — centered with a nudge so the slit doesn't visually
            // pull them off-center.
            Text(agent.initials)
                .font(MonolithFont.mono(size: size.initialFontSize, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.leading, size.slitWidth)
        }
        .frame(width: dim, height: dim)
        .clipShape(RoundedRectangle(cornerRadius: radius))
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
        AgentAvatar(agent: MockAgents.dispatch, size: .md)
        AgentAvatar(agent: MockAgents.dispatch, size: .lg)
        AgentAvatar(agent: MockAgents.dispatch, size: .xl)
        AgentAvatar(agent: MockAgents.dispatch, size: .xxl)
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
