//
//  WorkspaceHomeView.swift
//  Workspace
//
//  Screen 01 — Workspace home. v0.3 layout:
//  - Workspace icon (32pt rounded square with gradient + slit)
//  - Header: icon + "Raava Ops ▾" with presence line below
//  - Glass search "jump to..."
//  - Horizontal row of glass shortcut pills
//  - CHANNELS section (IBM Plex Sans 13pt uppercase, +) with 36pt # icon rows
//  - DIRECT MESSAGES section with avatar + presence + preview + time + badge
//

import SwiftUI

@MainActor
final class WorkspaceHomeViewModel: ObservableObject {
    @Published var workspace: Workspace?
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    private let workspaceRepo: WorkspaceRepository

    init(workspaceRepo: WorkspaceRepository) {
        self.workspaceRepo = workspaceRepo
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            self.workspace = try await workspaceRepo.loadCurrentWorkspace()
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct WorkspaceHomeView: View {
    @StateObject private var viewModel: WorkspaceHomeViewModel
    var onOpenChannel: ((ChannelID) -> Void)?
    var onOpenDM: ((DMID) -> Void)?
    var onOpenInviteAgent: (() -> Void)?

    init(
        workspaceRepo: WorkspaceRepository,
        onOpenChannel: ((ChannelID) -> Void)? = nil,
        onOpenDM: ((DMID) -> Void)? = nil,
        onOpenInviteAgent: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: WorkspaceHomeViewModel(workspaceRepo: workspaceRepo)
        )
        self.onOpenChannel = onOpenChannel
        self.onOpenDM = onOpenDM
        self.onOpenInviteAgent = onOpenInviteAgent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    searchBar
                        .padding(.horizontal, MonolithTheme.Spacing.lg)
                        .padding(.top, MonolithTheme.Spacing.md)
                    shortcutsRow
                        .padding(.top, MonolithTheme.Spacing.md)
                    sectionHeader("CHANNELS", onAdd: { onOpenInviteAgent?() })
                    channelsSection
                    sectionHeader("DIRECT MESSAGES", onAdd: nil)
                    dmsSection
                    Spacer().frame(height: MonolithTheme.Spacing.xxxl)
                }
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task {
            if viewModel.workspace == nil {
                await viewModel.load()
            }
        }
    }

    // MARK: header — workspace icon + name + presence line
    private var header: some View {
        HStack(alignment: .center, spacing: MonolithTheme.Spacing.md) {
            workspaceIcon
            VStack(alignment: .leading, spacing: 2) {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text(viewModel.workspace?.name ?? "…")
                            .font(MonolithFont.sans(size: 22, weight: .semibold))
                            .foregroundColor(MonolithTheme.Colors.textPrimary)
                        Text("\u{25BE}")
                            .font(MonolithFont.sans(size: 14))
                            .foregroundColor(MonolithTheme.Colors.textTertiary)
                    }
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch workspace")
                // Presence line: green dot + "2 teammates · 8 agents running"
                HStack(spacing: 6) {
                    PresenceDot(state: .running, size: 7)
                    Text("2 teammates · 8 agents running")
                        .font(MonolithFont.sans(size: 13))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.md)
        .padding(.bottom, MonolithTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 32pt rounded-square gradient + slit. The blue/teal gradient is the
    /// ONE permitted functional use of accent colours (per brand note).
    private var workspaceIcon: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    LinearGradient(
                        colors: [
                            MonolithTheme.Palette.accentBlue.opacity(0.3),
                            MonolithTheme.Palette.accentTeal.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(MonolithTheme.Glass.border, lineWidth: 1)
                )
            Rectangle()
                .fill(MonolithTheme.Colors.textPrimary)
                .frame(width: 2, height: 18)
                .opacity(0.8)
                .offset(x: 7)
        }
        .frame(width: 32, height: 32)
    }

    // MARK: glass search — "jump to..."
    private var searchBar: some View {
        Button(action: {}) {
            HStack(spacing: MonolithTheme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                Text("jump to...")
                    .font(MonolithFont.sans(size: 15))
                    .foregroundColor(MonolithTheme.Colors.textMuted)
                Spacer()
            }
            .padding(.horizontal, MonolithTheme.Spacing.lg)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial)
            .background(MonolithTheme.Glass.bg)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                    .stroke(MonolithTheme.Glass.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search, jump to channel or DM")
    }

    // MARK: shortcut pills row
    private var shortcutsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ShortcutPill(systemImage: "bubble.left.and.bubble.right",
                             label: "Threads",
                             count: "3")
                ShortcutPill(systemImage: "bell",
                             label: "Activity",
                             count: "12 new")
                ShortcutPill(systemImage: "tray",
                             label: "Drafts & sent",
                             count: "2")
            }
            .padding(.horizontal, MonolithTheme.Spacing.lg)
        }
    }

    // MARK: section header
    private func sectionHeader(_ title: String, onAdd: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(MonolithFont.sans(size: 13, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
            if let onAdd = onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MonolithTheme.Colors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.04))
                        .overlay(
                            Circle().stroke(MonolithTheme.Glass.border, lineWidth: 1)
                        )
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(title.lowercased())")
            }
        }
        .padding(.leading, MonolithTheme.Spacing.lg)
        .padding(.trailing, MonolithTheme.Spacing.sm)
        .padding(.top, MonolithTheme.Spacing.xl)
        .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: channels
    private var channelsSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.workspace?.channels ?? []) { channel in
                channelRow(channel)
            }
        }
    }

    private func channelRow(_ channel: Channel) -> some View {
        Button(action: { onOpenChannel?(channel.id) }) {
            HStack(spacing: MonolithTheme.Spacing.md) {
                // 36pt rounded-square icon with # inside
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(MonolithTheme.Glass.border, lineWidth: 1)
                        )
                    Text("#")
                        .font(MonolithFont.sans(size: 15, weight: .semibold))
                        .foregroundColor(MonolithTheme.Colors.textSecondary)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .font(MonolithFont.sans(size: 16, weight: channel.unread > 0 ? .semibold : .regular))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
                    if channel.unread > 0 {
                        Text(previewForChannel(channel))
                            .font(MonolithFont.sans(size: 13))
                            .foregroundColor(MonolithTheme.Colors.textTertiary)
                            .lineLimit(1)
                    } else if let topic = channel.topic, !topic.isEmpty {
                        Text(topic)
                            .font(MonolithFont.sans(size: 13))
                            .foregroundColor(MonolithTheme.Colors.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if channel.unread > 0 {
                    unreadBadge(channel.unread)
                }
            }
            .padding(.horizontal, MonolithTheme.Spacing.xl)
            .padding(.vertical, MonolithTheme.Spacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Best-effort preview string for unread channel rows. In a real
    /// implementation this would come from the repository; for the mock
    /// we pattern-match on channel slug.
    private func previewForChannel(_ channel: Channel) -> String {
        switch channel.name {
        case "client-ops":  return "dispatch · overnight triage for IWP complete"
        case "engineering": return "herald · deploy pipeline green for release-1.14"
        default:            return "new activity"
        }
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(MonolithFont.sans(size: 11, weight: .bold))
            .foregroundColor(MonolithTheme.Palette.void)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 6)
            .background(MonolithTheme.Palette.snow)
            .clipShape(Capsule())
    }

    // MARK: DMs
    private var dmsSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.workspace?.dms ?? []) { dm in
                dmRow(dm)
            }
        }
    }

    private func dmRow(_ dm: DirectMessage) -> some View {
        Button(action: { onOpenDM?(dm.id) }) {
            HStack(spacing: MonolithTheme.Spacing.md) {
                MemberAvatarWithPresence(member: dm.counterpart, size: .lg)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dm.counterpart.displayName)
                            .font(dm.counterpart.isAgent
                                  ? MonolithFont.mono(size: 14, weight: .semibold)
                                  : MonolithFont.sans(size: 16, weight: .semibold))
                            .foregroundColor(MonolithTheme.Colors.textPrimary)
                        if dm.counterpart.isAgent {
                            Text("agent")
                                .font(MonolithFont.mono(size: 10, weight: .medium))
                                .foregroundColor(MonolithTheme.Colors.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.04))
                                .overlay(
                                    Capsule()
                                        .stroke(MonolithTheme.Glass.border, lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                    }
                    Text(preview(for: dm))
                        .font(MonolithFont.sans(size: 13))
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(timeLabel(for: dm))
                        .font(MonolithFont.sans(size: 11))
                        .foregroundColor(MonolithTheme.Colors.textMuted)
                    if dm.unread > 0 {
                        unreadBadge(dm.unread)
                    }
                }
            }
            .padding(.horizontal, MonolithTheme.Spacing.xl)
            .padding(.vertical, MonolithTheme.Spacing.md)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func preview(for dm: DirectMessage) -> String {
        switch dm.counterpart.kind {
        case .agent(let a):
            switch a.handle {
            case "dispatch": return "drafted TLH reply for Greg — ready for review"
            case "scout":    return "JobNimbus mapping paused — awaiting sample data"
            case "warden":   return "overnight recon complete, no critical findings"
            case "pulse":    return "standby — no active task"
            case "herald":   return "deploy pipeline green for release-1.14"
            default:         return "no recent message"
            }
        case .human(let h):
            return h.displayName == "Sofia Chang"
                ? "sent CSV for JobNimbus validation"
                : "last active earlier today"
        }
    }

    private func timeLabel(for dm: DirectMessage) -> String {
        switch dm.counterpart.kind {
        case .agent(let a):
            switch a.handle {
            case "dispatch": return "2:05 PM"
            case "scout":    return "8:51 AM"
            case "warden":   return "8:54 AM"
            case "herald":   return "yesterday"
            default:         return "—"
            }
        case .human: return "11:24 AM"
        }
    }
}

#Preview("WorkspaceHomeView") {
    WorkspaceHomeView(workspaceRepo: MockWorkspaceRepository())
}
