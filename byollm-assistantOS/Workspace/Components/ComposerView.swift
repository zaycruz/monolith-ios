//
//  ComposerView.swift
//  Workspace
//
//  Bottom message composer. Includes a row for mention chips (if any),
//  the text input, and a small toolbar (attach / @ / send).
//

import SwiftUI

struct ComposerView: View {
    @Binding var text: String
    var mentions: [Member]
    var placeholder: String
    var onSend: (() -> Void)?
    var onMention: (() -> Void)?
    var onAttach: (() -> Void)?

    init(
        text: Binding<String>,
        mentions: [Member] = [],
        placeholder: String = "Message…",
        onSend: (() -> Void)? = nil,
        onMention: (() -> Void)? = nil,
        onAttach: (() -> Void)? = nil
    ) {
        self._text = text
        self.mentions = mentions
        self.placeholder = placeholder
        self.onSend = onSend
        self.onMention = onMention
        self.onAttach = onAttach
    }

    var body: some View {
        VStack(spacing: 0) {
            if !mentions.isEmpty {
                mentionChipsRow
            }
            HStack(alignment: .bottom, spacing: MonolithTheme.Spacing.sm) {
                attachButton
                textField
                mentionButton
                sendButton
            }
            .padding(.horizontal, MonolithTheme.Spacing.md)
            .padding(.vertical, MonolithTheme.Spacing.sm)
        }
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle()
                .fill(MonolithTheme.Colors.borderSoft)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: mention chips
    private var mentionChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(mentions) { m in
                    mentionChip(for: m)
                }
            }
            .padding(.horizontal, MonolithTheme.Spacing.md)
            .padding(.top, MonolithTheme.Spacing.sm)
        }
    }

    @ViewBuilder
    private func mentionChip(for member: Member) -> some View {
        HStack(spacing: 4) {
            switch member.kind {
            case .human(let h): HumanAvatar(human: h, size: .xs)
            case .agent(let a): AgentAvatar(agent: a, size: .xs)
            }
            Text("@\(member.displayName)")
                .font(MonolithFont.mono(size: 11, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(MonolithTheme.Colors.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill)
                .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill))
    }

    // MARK: text field
    private var textField: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(MonolithFont.sans(size: 14))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(MonolithFont.sans(size: 14))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 36, maxHeight: 120)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        }
        .background(MonolithTheme.Colors.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
    }

    // MARK: toolbar buttons
    private var attachButton: some View {
        Button(action: { onAttach?() }) {
            Image(systemName: "paperclip")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Attach")
    }

    private var mentionButton: some View {
        Button(action: { onMention?() }) {
            Text("@")
                .font(MonolithFont.mono(size: 16, weight: .bold))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mention")
    }

    private var sendButton: some View {
        Button(action: { onSend?() }) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(sendEnabled
                                 ? MonolithTheme.Colors.textPrimary
                                 : MonolithTheme.Colors.textMuted)
                .frame(width: 36, height: 36)
                .background(sendEnabled
                            ? MonolithTheme.Colors.accent
                            : MonolithTheme.Colors.bgPanel)
                .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(!sendEnabled)
        .accessibilityLabel("Send")
    }

    private var sendEnabled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview("Composer") {
    struct Wrap: View {
        @State var text: String = ""
        var body: some View {
            VStack {
                Spacer()
                ComposerView(
                    text: $text,
                    mentions: [MockMembers.dispatch],
                    placeholder: "Message #client-ops"
                )
            }
            .background(MonolithTheme.Colors.bgBase)
        }
    }
    return Wrap()
}
