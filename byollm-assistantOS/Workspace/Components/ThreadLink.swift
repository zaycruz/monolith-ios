//
//  ThreadLink.swift
//  Workspace
//
//  The "3 replies · avatars" link that sits below a parent message.
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
                    .font(MonolithFont.mono(size: 11, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.accent)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MonolithTheme.Spacing.sm)
            .padding(.vertical, 4)
            .background(MonolithTheme.Colors.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                    .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
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
                        Circle().stroke(MonolithTheme.Colors.bgElevated, lineWidth: 1.5)
                            .opacity(member.isAgent ? 0 : 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MonolithTheme.AvatarSize.sm.agentCornerRadius)
                            .stroke(MonolithTheme.Colors.bgElevated, lineWidth: 1.5)
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
