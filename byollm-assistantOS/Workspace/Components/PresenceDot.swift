//
//  PresenceDot.swift
//  Workspace
//
//  Small status indicator that overlays the bottom-trailing corner of a
//  member avatar. 12pt at size .lg. Running / online uses the stateRunning
//  green with a soft glow; offline / idle uses iron grey.
//

import SwiftUI

enum PresenceState: Equatable {
    case running
    case idle
    case offline
    case error
    case warning

    init(agentStatus: AgentStatus) {
        switch agentStatus {
        case .running: self = .running
        case .idle:    self = .idle
        case .error:   self = .error
        }
    }

    init(humanOnline: Bool) {
        self = humanOnline ? .running : .offline
    }
}

struct PresenceDot: View {
    let state: PresenceState
    let size: CGFloat

    init(state: PresenceState, size: CGFloat = 12) {
        self.state = state
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(MonolithTheme.Palette.obsidian, lineWidth: min(2.5, size * 0.22))
            )
            .shadow(
                color: glowColor.opacity(glowOpacity),
                radius: glowRadius
            )
            .accessibilityHidden(true)
    }

    private var fillColor: Color {
        switch state {
        case .running: return MonolithTheme.Colors.statusRunning
        case .idle:    return MonolithTheme.Colors.statusIdle
        case .offline: return MonolithTheme.Palette.iron
        case .error:   return MonolithTheme.Colors.statusError
        case .warning: return MonolithTheme.Colors.statusWarning
        }
    }

    private var glowColor: Color { fillColor }

    private var glowOpacity: Double {
        switch state {
        case .running, .error, .warning: return 0.5
        case .idle, .offline:            return 0
        }
    }

    private var glowRadius: CGFloat {
        switch state {
        case .running, .error, .warning: return 4
        case .idle, .offline:            return 0
        }
    }
}

/// Composite: wraps any avatar with a presence dot in the bottom-trailing
/// corner. Use the Member / Agent / Human overloads for convenience.
struct AvatarWithPresence<Content: View>: View {
    let size: MonolithTheme.AvatarSize
    let state: PresenceState?
    let content: () -> Content

    init(
        size: MonolithTheme.AvatarSize,
        state: PresenceState?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.size = size
        self.state = state
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content()
            if let state = state {
                PresenceDot(state: state, size: size.presenceDotSize)
                    .offset(x: size.presenceDotSize * 0.15, y: size.presenceDotSize * 0.15)
            }
        }
        .frame(
            width: size.dimension + (state != nil ? size.presenceDotSize * 0.15 : 0),
            height: size.dimension + (state != nil ? size.presenceDotSize * 0.15 : 0),
            alignment: .topLeading
        )
    }
}

// MARK: - Convenience builders

extension AvatarWithPresence where Content == AgentAvatar {
    init(agent: Agent, size: MonolithTheme.AvatarSize = .lg, showPresence: Bool = true) {
        self.init(
            size: size,
            state: showPresence ? PresenceState(agentStatus: agent.status) : nil,
            content: { AgentAvatar(agent: agent, size: size) }
        )
    }
}

extension AvatarWithPresence where Content == HumanAvatar {
    init(human: Human, size: MonolithTheme.AvatarSize = .lg, showPresence: Bool = true) {
        self.init(
            size: size,
            state: showPresence ? PresenceState(humanOnline: human.online) : nil,
            content: { HumanAvatar(human: human, size: size) }
        )
    }
}

/// Dispatches to the right avatar type for a Member. Lives outside the
/// extension so the generic Content parameter stays simple at call sites.
struct MemberAvatarWithPresence: View {
    let member: Member
    let size: MonolithTheme.AvatarSize
    let showPresence: Bool

    init(member: Member, size: MonolithTheme.AvatarSize = .lg, showPresence: Bool = true) {
        self.member = member
        self.size = size
        self.showPresence = showPresence
    }

    var body: some View {
        switch member.kind {
        case .human(let h):
            AvatarWithPresence(human: h, size: size, showPresence: showPresence)
        case .agent(let a):
            AvatarWithPresence(agent: a, size: size, showPresence: showPresence)
        }
    }
}

#Preview("Presence dots") {
    HStack(spacing: 16) {
        AvatarWithPresence(agent: MockAgents.dispatch, size: .lg)
        AvatarWithPresence(human: MockHumans.zay, size: .lg)
        AvatarWithPresence(human: MockHumans.jason, size: .lg)
        AvatarWithPresence(agent: MockAgents.dispatch, size: .xxl)
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
