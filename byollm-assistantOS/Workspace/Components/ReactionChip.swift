//
//  ReactionChip.swift
//  Workspace
//
//  Symbol-based reaction pills (✓ ! ? ✗ ↻ +). Not emoji, by design.
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
            HStack(spacing: 4) {
                Text(reaction.symbol.rawValue)
                    .font(MonolithFont.mono(size: 11, weight: .medium))
                    .foregroundColor(foregroundColor)
                Text("\(reaction.count)")
                    .font(MonolithFont.mono(size: 11))
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill))
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
            ? MonolithTheme.Colors.bgHover
            : MonolithTheme.Colors.bgElevated
    }

    private var borderColor: Color {
        reaction.viewerReacted
            ? MonolithTheme.Colors.borderStrong
            : MonolithTheme.Colors.borderSoft
    }
}

/// A "+" chip used to open the reaction picker.
struct AddReactionChip: View {
    var onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) { self.onTap = onTap }

    var body: some View {
        Button(action: { onTap?() }) {
            Text(ReactionSymbol.plus.rawValue)
                .font(MonolithFont.mono(size: 12, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(MonolithTheme.Colors.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill)
                        .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.pill))
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
        ReactionChip(reaction: Reaction(symbol: .veto, count: 1))
        ReactionChip(reaction: Reaction(symbol: .retry, count: 1))
        AddReactionChip()
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
