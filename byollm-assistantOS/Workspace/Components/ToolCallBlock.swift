//
//  ToolCallBlock.swift
//  Workspace
//
//  Tool calls are *children of a message* — they render INLINE, before the
//  text body, not as separate messages. Layout: head (name + status), body
//  (args), foot (duration + result summary).
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
        .background(MonolithTheme.Colors.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
    }

    // MARK: head
    private var head: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
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
        .background(MonolithTheme.Colors.bgPanel)
    }

    // MARK: body
    private var body_: some View {
        VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, MonolithTheme.Spacing.sm)
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
        .background(MonolithTheme.Colors.bgSurface)
    }

    private var statusColor: Color {
        switch call.status {
        case .ok:      return MonolithTheme.Colors.statusRunning
        case .err:     return MonolithTheme.Colors.statusError
        case .running: return MonolithTheme.Colors.accent
        }
    }

    private var statusLabel: String {
        switch call.status {
        case .ok:      return "OK"
        case .err:     return "ERR"
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
