//
//  DMsTabView.swift
//  Workspace
//
//  Tab screen — dedicated list of direct messages. v0.3 treatment:
//  - Large "Direct messages" title header (IBM Plex Sans 28pt)
//  - Row uses MemberAvatarWithPresence, 56pt row height, preview + time,
//    unread badge (snow capsule) on the right.
//

import SwiftUI

@MainActor
final class DMsTabViewModel: ObservableObject {
    @Published var dms: [DirectMessage] = []
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
            let ws = try await workspaceRepo.loadCurrentWorkspace()
            self.dms = ws.dms
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct DMsTabView: View {
    @StateObject private var viewModel: DMsTabViewModel
    var onOpenDM: ((DMID) -> Void)?

    init(
        workspaceRepo: WorkspaceRepository,
        onOpenDM: ((DMID) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: DMsTabViewModel(workspaceRepo: workspaceRepo)
        )
        self.onOpenDM = onOpenDM
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.dms) { dm in
                        row(dm)
                    }
                }
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task {
            if viewModel.dms.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: header
    private var header: some View {
        HStack {
            Text("Direct messages")
                .font(MonolithFont.sans(size: 28, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.lg)
        .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: row
    @ViewBuilder
    private func row(_ dm: DirectMessage) -> some View {
        if dm.counterpart.isAgent {
            Button(action: { onOpenDM?(dm.id) }) {
                rowContent(dm)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(dm)
        }
    }

    private func rowContent(_ dm: DirectMessage) -> some View {
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
                            .overlay(Capsule().stroke(MonolithTheme.Glass.border, lineWidth: 1))
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
                if dm.unread > 0 { unreadBadge(dm.unread) }
            }
        }
        .padding(.horizontal, MonolithTheme.Spacing.xl)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
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
        case .human:
            return "tap coming soon"
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

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(MonolithFont.sans(size: 11, weight: .bold))
            .foregroundColor(MonolithTheme.Palette.void)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 6)
            .background(MonolithTheme.Palette.snow)
            .clipShape(Capsule())
    }
}

#Preview("DMsTabView") {
    DMsTabView(workspaceRepo: MockWorkspaceRepository())
}
