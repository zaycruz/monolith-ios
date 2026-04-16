//
//  ActivityTabView.swift
//  Workspace
//
//  Screen 07 — mentions and notable events feed. v0.3 layout:
//  - Large "Activity" title header
//  - Glass "Filter activity..." search
//  - "New" + "Earlier today" sections
//  - Activity items: avatar + headline (bold name + action + #channel)
//    + preview + time
//

import SwiftUI

@MainActor
final class ActivityTabViewModel: ObservableObject {
    @Published var events: [ActivityEvent] = []
    @Published var loading: Bool = false
    @Published var errorMessage: String?

    private let activityRepo: ActivityRepository

    init(activityRepo: ActivityRepository) {
        self.activityRepo = activityRepo
    }

    func load() async {
        loading = true
        defer { loading = false }
        do {
            self.events = try await activityRepo.fetchRecent()
        } catch {
            self.errorMessage = "\(error)"
        }
    }
}

struct ActivityTabView: View {
    @StateObject private var viewModel: ActivityTabViewModel
    var onOpenChannel: ((ChannelID) -> Void)?
    var onOpenThread: ((ThreadID) -> Void)?
    var onOpenDM: ((DMID) -> Void)?

    init(
        activityRepo: ActivityRepository,
        onOpenChannel: ((ChannelID) -> Void)? = nil,
        onOpenThread: ((ThreadID) -> Void)? = nil,
        onOpenDM: ((DMID) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: ActivityTabViewModel(activityRepo: activityRepo)
        )
        self.onOpenChannel = onOpenChannel
        self.onOpenThread = onOpenThread
        self.onOpenDM = onOpenDM
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    searchBar
                        .padding(.horizontal, MonolithTheme.Spacing.lg)
                        .padding(.top, MonolithTheme.Spacing.md)
                    if !newEvents.isEmpty {
                        sectionHeader("NEW")
                        ForEach(newEvents) { event in
                            eventRow(event)
                        }
                    }
                    if !earlierEvents.isEmpty {
                        sectionHeader("EARLIER TODAY")
                        ForEach(earlierEvents) { event in
                            eventRow(event)
                        }
                    }
                    Spacer().frame(height: MonolithTheme.Spacing.xxxl)
                }
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task {
            if viewModel.events.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: header — large "Activity" title
    private var header: some View {
        HStack {
            Text("Activity")
                .font(MonolithFont.sans(size: 28, weight: .semibold))
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.top, MonolithTheme.Spacing.lg)
        .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: search
    private var searchBar: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textMuted)
            Text("Filter activity...")
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
    }

    // MARK: section splitting
    /// "New" = last 2h (mock threshold) — first two items in our fixtures.
    private var newEvents: [ActivityEvent] {
        Array(viewModel.events.prefix(2))
    }
    private var earlierEvents: [ActivityEvent] {
        Array(viewModel.events.dropFirst(2))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(MonolithFont.sans(size: 13, weight: .semibold))
            .tracking(0.3)
            .foregroundColor(MonolithTheme.Colors.textTertiary)
            .padding(.horizontal, MonolithTheme.Spacing.lg)
            .padding(.top, MonolithTheme.Spacing.xl)
            .padding(.bottom, MonolithTheme.Spacing.sm)
    }

    // MARK: row
    @ViewBuilder
    private func eventRow(_ event: ActivityEvent) -> some View {
        if canNavigate(event) {
            Button(action: { open(event) }) {
                rowContent(event)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(event)
        }
    }

    private func rowContent(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top, spacing: MonolithTheme.Spacing.md) {
            actorAvatar(event.actor)
            VStack(alignment: .leading, spacing: 4) {
                headline(for: event)
                Text(event.summary)
                    .font(MonolithFont.sans(size: 14))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(timeLabel(event.timestamp))
                .font(MonolithFont.sans(size: 12))
                .foregroundColor(MonolithTheme.Colors.textMuted)
                .padding(.top, 2)
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Composed headline: bold actor name + action verb + target (channel/thread/dm).
    @ViewBuilder
    private func headline(for event: ActivityEvent) -> some View {
        let isAgent = event.actor.isAgent
        let nameFont = isAgent
            ? MonolithFont.mono(size: 14, weight: .semibold)
            : MonolithFont.sans(size: 15, weight: .semibold)

        HStack(spacing: 0) {
            Text(event.actor.displayName)
                .font(nameFont)
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Text(" \(actionPhrase(for: event)) ")
                .font(MonolithFont.sans(size: 14))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Text(event.target)
                .font(MonolithFont.sans(size: 14, weight: .medium))
                .foregroundColor(MonolithTheme.Colors.textSecondary)
        }
        .lineLimit(2)
    }

    @ViewBuilder
    private func actorAvatar(_ actor: Member) -> some View {
        MemberAvatarWithPresence(member: actor, size: .lg, showPresence: false)
    }

    // MARK: navigation
    private func canNavigate(_ event: ActivityEvent) -> Bool {
        event.threadID != nil || event.dmID != nil || event.channelID != nil
    }

    private func open(_ event: ActivityEvent) {
        if let tid = event.threadID {
            onOpenThread?(tid)
        } else if let did = event.dmID {
            onOpenDM?(did)
        } else if let cid = event.channelID {
            onOpenChannel?(cid)
        }
    }

    // MARK: labels
    private func actionPhrase(for event: ActivityEvent) -> String {
        switch event.kind {
        case .mention:        return "mentioned you in"
        case .flag:           return "flagged in"
        case .threadReply:    return "replied in"
        case .agentCompleted: return "completed in"
        case .agentStatus:    return "status ·"
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        df.amSymbol = "AM"
        df.pmSymbol = "PM"
        return df.string(from: date)
    }
}

#Preview("ActivityTabView") {
    ActivityTabView(activityRepo: MockActivityRepository())
}
