//
//  GlassNavBar.swift
//  Workspace
//
//  Reusable glass navigation header used across channel / thread / DM /
//  detail / launch screens. Translucent `.ultraThinMaterial` background
//  with a subtle 1pt bottom border. Optional back button and trailing
//  action slot.
//

import SwiftUI

struct GlassNavBar<Leading: View, Title: View, Trailing: View>: View {
    let leading: Leading
    let title: Title
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder title: () -> Title,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.leading = leading()
        self.title = title()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: MonolithTheme.Spacing.md) {
            leading
                .frame(minWidth: 36, minHeight: 36, alignment: .leading)

            title
                .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .frame(minHeight: 52)
        .background(.ultraThinMaterial)
        .background(MonolithTheme.Palette.obsidian.opacity(0.5))
        .overlay(
            Rectangle()
                .fill(MonolithTheme.Glass.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

/// Convenience back button styled to match the v0.3 nav pattern — a
/// chevron with a 36pt hit target.
struct GlassNavBackButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// Convenience close button (x) used for modal sheets.
struct GlassNavCloseButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

/// Two-line title element commonly paired with the glass nav bar —
/// primary title + smaller subtitle.
struct GlassNavTitle: View {
    let title: String
    let subtitle: String?
    let titleIsMono: Bool

    init(title: String, subtitle: String? = nil, titleIsMono: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.titleIsMono = titleIsMono
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(
                    titleIsMono
                        ? MonolithFont.mono(size: 17, weight: .semibold)
                        : MonolithFont.sans(size: 17, weight: .semibold)
                )
                .foregroundColor(MonolithTheme.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(MonolithFont.sans(size: 12))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview("GlassNavBar") {
    VStack(spacing: 0) {
        GlassNavBar(
            leading: { GlassNavBackButton(onTap: {}) },
            title: { GlassNavTitle(title: "client-ops", subtitle: "9 members · 3 agents") },
            trailing: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }
        )
        Spacer()
    }
    .background(MonolithTheme.Colors.bgBase)
}
