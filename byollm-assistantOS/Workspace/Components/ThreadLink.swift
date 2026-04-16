//
//  ThreadLink.swift
//  Workspace
//
//  The "3 replies · avatars" link that sits below a parent message.
//  v0.3 treatment: 8pt 14pt padding, 12pt radius, glass background.
//

import SwiftUI

struct ThreadLink: View {
    let summary: ThreadSummary
    var onTap: (() -> Void)?

    init(summary: ThreadSummary, onTap: (() -> Void)? = nil) {
        self.summary = summary
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: MonolithTheme.Spacing.sm) {
                avatarStack
                Text(replyLabel)
                    .font(MonolithFont.sans(size: 13, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MonolithTheme.Glass.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(summary.replyCount) thread replies")
    }

    private var replyLabel: String {
        summary.replyCount == 1 ? "1 reply" : "\(summary.replyCount) replies"
    }

    private var avatarStack: some View {
        HStack(spacing: -6) {
            ForEach(summary.participants.prefix(3)) { member in
                avatar(for: member)
                    .overlay(
                        Circle().stroke(MonolithTheme.Palette.obsidian, lineWidth: 1.5)
                            .opacity(member.isAgent ? 0 : 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MonolithTheme.AvatarSize.sm.agentCornerRadius)
                            .stroke(MonolithTheme.Palette.obsidian, lineWidth: 1.5)
                            .opacity(member.isAgent ? 1 : 0)
                    )
            }
        }
    }

    @ViewBuilder
    private func avatar(for member: Member) -> some View {
        switch member.kind {
        case .human(let h): HumanAvatar(human: h, size: .sm)
        case .agent(let a): AgentAvatar(agent: a, size: .sm)
        }
    }
}

#Preview("ThreadLink") {
    ThreadLink(summary: MockThreads.clientOpsTriageThread)
        .padding()
        .background(MonolithTheme.Colors.bgBase)
}
