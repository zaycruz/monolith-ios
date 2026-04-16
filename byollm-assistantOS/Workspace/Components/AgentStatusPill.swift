//
//  AgentStatusPill.swift
//  Workspace
//
//  "running · healthy" green-tinted pill used in the agent-detail hero.
//  For idle / error / warning states the tint shifts accordingly.
//

import SwiftUI

struct AgentStatusPill: View {
    let status: AgentStatus
    let label: String?

    init(status: AgentStatus, label: String? = nil) {
        self.status = status
        self.label = label
    }

    var body: some View {
        HStack(spacing: 6) {
            PresenceDot(state: PresenceState(agentStatus: status), size: 7)
            Text(resolvedLabel)
                .font(MonolithFont.mono(size: 12, weight: .medium))
                .foregroundColor(foregroundColor)
        }
        .padding(.horizontal, MonolithTheme.Spacing.md)
        .padding(.vertical, 5)
        .background(backgroundTint)
        .overlay(
            Capsule()
                .stroke(borderTint, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var resolvedLabel: String {
        if let label = label { return label }
        switch status {
        case .running: return "running · healthy"
        case .idle:    return "idle"
        case .error:   return "error"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .running: return MonolithTheme.Colors.statusRunning
        case .idle:    return MonolithTheme.Colors.textSecondary
        case .error:   return MonolithTheme.Colors.statusError
        }
    }

    private var backgroundTint: Color {
        switch status {
        case .running: return MonolithTheme.Colors.statusRunning.opacity(0.12)
        case .idle:    return MonolithTheme.Glass.bg
        case .error:   return MonolithTheme.Colors.statusError.opacity(0.12)
        }
    }

    private var borderTint: Color {
        switch status {
        case .running: return MonolithTheme.Colors.statusRunning.opacity(0.3)
        case .idle:    return MonolithTheme.Glass.border
        case .error:   return MonolithTheme.Colors.statusError.opacity(0.3)
        }
    }
}

#Preview("AgentStatusPill") {
    VStack(spacing: 12) {
        AgentStatusPill(status: .running)
        AgentStatusPill(status: .idle, label: "idle · standby")
        AgentStatusPill(status: .error, label: "error · check logs")
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
