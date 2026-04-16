//
//  MessageRow.swift
//  Workspace
//
//  Core message row. Layout: 32pt avatar slot + flexible body.
//  - Human vs agent styling differs: agents get mono names + AGENT tag.
//  - Tool calls render INLINE BEFORE the text body.
//  - Collapsed rows (same author within 2 min) hide the avatar and header.
//

import SwiftUI

struct MessageRow: View {
    let message: WorkspaceMessage
    var onOpenThread: ((ThreadID) -> Void)?
    var onToggleReaction: ((ReactionSymbol) -> Void)?

    init(
        message: WorkspaceMessage,
        onOpenThread: ((ThreadID) -> Void)? = nil,
        onToggleReaction: ((ReactionSymbol) -> Void)? = nil
    ) {
        self.message = message
        self.onOpenThread = onOpenThread
        self.onToggleReaction = onToggleReaction
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
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, message.collapsed ? 2 : MonolithTheme.Spacing.sm)
    }

    // MARK: avatar slot — 32pt fixed
    @ViewBuilder
    private var avatarSlot: some View {
        Group {
            if message.collapsed {
                // Collapsed rows: reserve the same slot, render timestamp on hover/always-visible tiny.
                Text(Self.timeFormatter.string(from: message.timestamp))
                    .font(MonolithFont.mono(size: 9))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                    .frame(width: 32, alignment: .center)
            } else {
                switch message.author.kind {
                case .human(let h): HumanAvatar(human: h, size: .lg)
                case .agent(let a): AgentAvatar(agent: a, size: .lg)
                }
            }
        }
        .frame(width: 32, alignment: .top)
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
                .font(MonolithFont.mono(size: 10))
                .foregroundColor(MonolithTheme.Colors.textMuted)
        }
    }

    private var nameFont: Font {
        message.author.isAgent
            ? MonolithFont.mono(size: 13, weight: .medium)
            : MonolithFont.sans(size: 14, weight: .medium)
    }

    private var agentTag: some View {
        Text("AGENT")
            .font(MonolithFont.mono(size: 9, weight: .medium))
            .tracking(0.6)
            .foregroundColor(MonolithTheme.Colors.textTertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.sm)
                    .stroke(MonolithTheme.Colors.borderStrong, lineWidth: 1)
            )
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

    private var bodyFont: Font {
        message.author.isAgent
            ? MonolithFont.mono(size: 13)
            : MonolithFont.sans(size: 14)
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
