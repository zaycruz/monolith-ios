//
//  TabBar.swift
//  Workspace
//
//  Bottom tab bar: home / dms / activity / you.
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

    init(selection: Binding<WorkspaceTab>) {
        self._selection = selection
    }

    var body: some View {
        HStack(spacing: 0) {
            tab(.home, systemImage: "square.grid.2x2", label: "Home")
            tab(.dms, systemImage: "bubble.left.and.bubble.right", label: "DMs")
            tab(.activity, systemImage: "bell", label: "Activity")
            tab(.you, systemImage: "person.crop.circle", label: "You")
        }
        .padding(.top, MonolithTheme.Spacing.sm)
        .padding(.bottom, MonolithTheme.Spacing.xs)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle()
                .fill(MonolithTheme.Colors.borderSoft)
                .frame(height: 1),
            alignment: .top
        )
    }

    @ViewBuilder
    private func tab(_ tab: WorkspaceTab, systemImage: String, label: String) -> some View {
        let selected = (selection == tab)
        Button(action: { selection = tab }) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(MonolithFont.mono(size: 10, weight: .medium))
            }
            .foregroundColor(selected
                             ? MonolithTheme.Colors.textPrimary
                             : MonolithTheme.Colors.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview("TabBar") {
    struct Wrap: View {
        @State var sel: WorkspaceTab = .home
        var body: some View {
            VStack {
                Spacer()
                TabBar(selection: $sel)
            }
            .background(MonolithTheme.Colors.bgBase)
        }
    }
    return Wrap()
}
