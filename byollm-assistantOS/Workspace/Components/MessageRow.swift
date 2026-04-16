//
//  MessageRow.swift
//  Workspace
//
//  Core message row. Layout: 36pt avatar slot + flexible body.
//  - Human vs agent styling differs: agents get mono names + lowercase
//    glass `agent` pill. Avatar shape carries the distinction — no
//    coloured left border in v0.3.
//  - Tool calls render INLINE BEFORE the text body.
//  - Collapsed rows (same author within 2 min) hide the avatar and header.
//

import SwiftUI

struct MessageRow: View {
    let message: WorkspaceMessage
    var onOpenThread: ((ThreadID) -> Void)?
    var onToggleReaction: ((ReactionSymbol) -> Void)?
    var onOpenMember: ((Member) -> Void)?

    init(
        message: WorkspaceMessage,
        onOpenThread: ((ThreadID) -> Void)? = nil,
        onToggleReaction: ((ReactionSymbol) -> Void)? = nil,
        onOpenMember: ((Member) -> Void)? = nil
    ) {
        self.message = message
        self.onOpenThread = onOpenThread
        self.onToggleReaction = onToggleReaction
        self.onOpenMember = onOpenMember
    }

    var body: some View {
        HStack(alignment: .top, spacing: MonolithTheme.Spacing.md) {
            avatarSlot
            VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xs) {
                if !message.collapsed {
                    header
                }
                body_
                if let thread = message.thread {
                    ThreadLink(summary: thread) {
                        onOpenThread?(thread.id)
                    }
                }
                if !message.reactions.isEmpty {
                    reactions
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MonolithTheme.Spacing.xl)
        .padding(.top, MonolithTheme.Spacing.sm)
        .padding(.bottom, message.collapsed ? 2 : MonolithTheme.Spacing.md)
    }

    // MARK: avatar slot — 36pt fixed
    @ViewBuilder
    private var avatarSlot: some View {
        Group {
            if message.collapsed {
                // Collapsed rows: tiny timestamp in the reserved slot.
                Text(Self.timeFormatter.string(from: message.timestamp))
                    .font(MonolithFont.sans(size: 10))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                    .frame(width: 36, alignment: .center)
            } else {
                Button(action: { onOpenMember?(message.author) }) {
                    switch message.author.kind {
                    case .human(let h): HumanAvatar(human: h, size: .lg)
                    case .agent(let a): AgentAvatar(agent: a, size: .lg)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 36, alignment: .top)
    }

    // MARK: header (name + agent tag + timestamp)
    private var header: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Text(message.author.displayName)
                .font(nameFont)
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            if message.author.isAgent {
                agentTag
            }
            Text(Self.timeFormatter.string(from: message.timestamp))
                .font(MonolithFont.sans(size: 12))
                .foregroundColor(MonolithTheme.Colors.textMuted)
        }
    }

    private var nameFont: Font {
        message.author.isAgent
            ? MonolithFont.mono(size: 14, weight: .semibold)
            : MonolithFont.sans(size: 15, weight: .semibold)
    }

    /// Lowercase `agent` glass pill. Replaces the uppercase `AGENT` border
    /// tag used in v0.2.
    private var agentTag: some View {
        Text("agent")
            .font(MonolithFont.mono(size: 10, weight: .medium))
            .foregroundColor(MonolithTheme.Colors.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.04))
            .overlay(
                Capsule()
                    .stroke(MonolithTheme.Glass.border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }

    // MARK: body (tool calls inline BEFORE text)
    private var body_: some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            ForEach(message.toolCalls) { call in
                ToolCallBlock(call: call)
            }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(bodyFont)
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Body is IBM Plex Sans for both humans and agents — v0.3 reserves
    /// JetBrains Mono for names, tool calls, and runtime data only.
    private var bodyFont: Font {
        MonolithFont.sans(size: 15)
    }

    // MARK: reactions row
    private var reactions: some View {
        HStack(spacing: 6) {
            ForEach(message.reactions) { r in
                ReactionChip(reaction: r) {
                    onToggleReaction?(r.symbol)
                }
            }
            AddReactionChip {
                // Picker wiring — left as TODO for the real impl.
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        df.amSymbol = "AM"
        df.pmSymbol = "PM"
        return df
    }()
}

#Preview("MessageRow · human + agent + collapsed") {
    VStack(alignment: .leading, spacing: 0) {
        ForEach(MockMessages.clientOps) { m in
            MessageRow(message: m)
        }
    }
    .padding(.vertical)
    .background(MonolithTheme.Colors.bgBase)
}
