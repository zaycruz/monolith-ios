//
//  ToolCallBlock.swift
//  Workspace
//
//  Tool calls are *children of a message* — they render INLINE, before the
//  text body, not as separate messages. Layout: head (name + status), body
//  (args), foot (duration + result summary).
//
//  v0.3 treatment: glass card. An .ultraThinMaterial base with an overlay
//  dark translucent fill, 1pt glass border, and a 12pt corner radius.
//

import SwiftUI

struct ToolCallBlock: View {
    let call: ToolCall

    init(call: ToolCall) { self.call = call }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            if !call.args.isEmpty {
                body_
            }
            foot
        }
        .background(.ultraThinMaterial)
        .background(MonolithTheme.Glass.toolCardFill)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MonolithTheme.Glass.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: head
    private var head: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.5), radius: 2)
            Text(call.name)
                .font(MonolithFont.mono(size: 12, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
            Text(statusLabel)
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, MonolithTheme.Spacing.md)
        .padding(.vertical, MonolithTheme.Spacing.sm)
    }

    // MARK: body
    private var body_: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(call.args.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .firstTextBaseline, spacing: MonolithTheme.Spacing.sm) {
                    Text(pair.0)
                        .font(MonolithFont.mono(size: 11))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                    Text(pair.1)
                        .font(MonolithFont.mono(size: 11))
                        .foregroundColor(MonolithTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MonolithTheme.Spacing.md)
        .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: foot
    private var foot: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            if let ms = call.durationMs {
                Text("\(ms)ms")
                    .font(MonolithFont.mono(size: 10))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
            }
            if let summary = call.resultSummary {
                Text("·")
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                Text(summary)
                    .font(MonolithFont.mono(size: 10))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.md)
        .padding(.vertical, MonolithTheme.Spacing.xs)
        .background(Color.white.opacity(0.02))
    }

    private var statusColor: Color {
        switch call.status {
        case .ok:      return MonolithTheme.Colors.statusRunning
        case .err:     return MonolithTheme.Colors.statusError
        case .running: return MonolithTheme.Colors.statusWarning
        }
    }

    private var statusLabel: String {
        switch call.status {
        case .ok:      return "ok"
        case .err:     return "err"
        case .running: return "…"
        }
    }
}

#Preview("ToolCallBlock") {
    VStack(spacing: 12) {
        ToolCallBlock(call: MockMessages.clientOps[1].toolCalls[0])
        ToolCallBlock(call: MockMessages.zayDispatchDM[2].toolCalls[0])
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
