//
//  ShortcutPill.swift
//  Workspace
//
//  Glass pill shortcut used on the workspace-home screen for quick jumps
//  to Threads / Activity / Drafts. Horizontal capsule with icon + label
//  + optional count. Larger than a chip — hit target comfortably exceeds
//  44pt.
//

import SwiftUI

struct ShortcutPill: View {
    let systemImage: String
    let label: String
    let count: String?
    var onTap: (() -> Void)?

    init(
        systemImage: String,
        label: String,
        count: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.label = label
        self.count = count
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                Text(label)
                    .font(MonolithFont.sans(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                if let count = count {
                    Text(count)
                        .font(MonolithFont.sans(size: 12, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                }
            }
            .padding(.horizontal, MonolithTheme.Spacing.md)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial)
            .background(MonolithTheme.Glass.bg)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                    .stroke(MonolithTheme.Glass.borderSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(count.map { ", \($0)" } ?? "")")
    }
}

#Preview("Shortcut pills") {
    HStack(spacing: 8) {
        ShortcutPill(systemImage: "bubble.left.and.bubble.right", label: "Threads", count: "3")
        ShortcutPill(systemImage: "bell", label: "Activity", count: "12")
        ShortcutPill(systemImage: "tray", label: "Drafts", count: "2")
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
