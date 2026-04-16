//
//  ReactionChip.swift
//  Workspace
//
//  Symbol-based reaction pills (✓ ! ? ✗ ↻ +). Not emoji, by design.
//  v0.3 treatment: larger padding, 20pt radius, glass-ish fill and border.
//

import SwiftUI

struct ReactionChip: View {
    let reaction: Reaction
    var onTap: (() -> Void)?

    init(reaction: Reaction, onTap: (() -> Void)? = nil) {
        self.reaction = reaction
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 6) {
                Text(reaction.symbol.rawValue)
                    .font(MonolithFont.mono(size: 13, weight: .medium))
                    .foregroundColor(foregroundColor)
                Text("\(reaction.count)")
                    .font(MonolithFont.sans(size: 13, weight: .medium))
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.xl)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.xl))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(reaction.symbol.rawValue) \(reaction.count) reactions")
    }

    private var foregroundColor: Color {
        reaction.viewerReacted
            ? MonolithTheme.Colors.textPrimary
            : MonolithTheme.Colors.textSecondary
    }

    private var backgroundColor: Color {
        reaction.viewerReacted
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.04)
    }

    private var borderColor: Color {
        reaction.viewerReacted
            ? Color.white.opacity(0.12)
            : MonolithTheme.Glass.border
    }
}

/// A "+" chip used to open the reaction picker.
struct AddReactionChip: View {
    var onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) { self.onTap = onTap }

    var body: some View {
        Button(action: { onTap?() }) {
            Text(ReactionSymbol.plus.rawValue)
                .font(MonolithFont.mono(size: 13, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: MonolithTheme.Radius.xl)
                        .stroke(MonolithTheme.Glass.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.xl))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add reaction")
    }
}

#Preview("Reaction chips") {
    HStack {
        ReactionChip(reaction: Reaction(symbol: .ack, count: 3, viewerReacted: true))
        ReactionChip(reaction: Reaction(symbol: .flag, count: 1))
        ReactionChip(reaction: Reaction(symbol: .ask, count: 2))
        AddReactionChip()
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
