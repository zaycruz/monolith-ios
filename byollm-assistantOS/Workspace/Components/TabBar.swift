//
//  TabBar.swift
//  Workspace
//
//  Bottom tab bar: home / dms / activity / you.
//  v0.3 treatment: glass material background, 3pt x 48pt snow indicator
//  above the active icon at 50% opacity, 26pt icons, IBM Plex Sans 10pt
//  weight 500 labels. DMs tab carries an unread badge when viewer has
//  unread DMs.
//

import SwiftUI

enum WorkspaceTab: Hashable {
    case home
    case dms
    case activity
    case you
}

struct TabBar: View {
    @Binding var selection: WorkspaceTab
    /// Per-tab unread counts. Values <= 0 suppress the badge.
    var unreadDMs: Int
    var unreadActivity: Int

    init(
        selection: Binding<WorkspaceTab>,
        unreadDMs: Int = 0,
        unreadActivity: Int = 0
    ) {
        self._selection = selection
        self.unreadDMs = unreadDMs
        self.unreadActivity = unreadActivity
    }

    var body: some View {
        HStack(spacing: 0) {
            tab(.home, systemImage: "square.grid.2x2", label: "Home", badge: 0)
            tab(.dms, systemImage: "bubble.left.and.bubble.right", label: "DMs", badge: unreadDMs)
            tab(.activity, systemImage: "bell", label: "Activity", badge: unreadActivity)
            tab(.you, systemImage: "person.crop.circle", label: "You", badge: 0)
        }
        .padding(.top, 10)
        .padding(.bottom, MonolithTheme.Spacing.sm)
        .frame(minHeight: 72)
        .background(.ultraThinMaterial)
        .background(MonolithTheme.Palette.obsidian.opacity(0.45))
        .overlay(
            Rectangle()
                .fill(MonolithTheme.Glass.border)
                .frame(height: 1),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(MonolithTheme.Glass.highlight)
                .frame(height: 1)
                .padding(.top, 1),
            alignment: .top
        )
    }

    @ViewBuilder
    private func tab(_ tab: WorkspaceTab, systemImage: String, label: String, badge: Int) -> some View {
        let selected = (selection == tab)
        Button(action: { selection = tab }) {
            VStack(spacing: 4) {
                // Active indicator bar: 3pt x 48pt snow at 50% opacity,
                // sitting 12pt above the icon.
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(MonolithTheme.Colors.textPrimary.opacity(selected ? 0.5 : 0))
                    .frame(width: 48, height: 3)

                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(selected
                                         ? MonolithTheme.Colors.textPrimary
                                         : MonolithTheme.Colors.textTertiary)
                        .frame(width: 30, height: 30)
                    if badge > 0 {
                        unreadBadge(badge)
                            .offset(x: 6, y: -4)
                    }
                }
                Text(label)
                    .font(MonolithFont.sans(size: 10, weight: .medium))
                    .foregroundColor(selected
                                     ? MonolithTheme.Colors.textPrimary
                                     : MonolithTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(MonolithFont.sans(size: 10, weight: .bold))
            .foregroundColor(MonolithTheme.Palette.void)
            .frame(minWidth: 16, minHeight: 16)
            .padding(.horizontal, 4)
            .background(MonolithTheme.Palette.snow)
            .clipShape(Capsule())
    }
}

#Preview("TabBar") {
    struct Wrap: View {
        @State var sel: WorkspaceTab = .home
        var body: some View {
            VStack {
                Spacer()
                TabBar(selection: $sel, unreadDMs: 3, unreadActivity: 12)
            }
            .background(MonolithTheme.Colors.bgBase)
        }
    }
    return Wrap()
}
