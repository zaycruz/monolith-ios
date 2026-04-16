//
//  ActivityTabView.swift
//  Workspace
//
//  Tab screen — mentions and notable events feed. Sorted newest-first.
//  Rows with a channelID / threadID / dmID are tappable; others render
//  as non-navigable (e.g. standalone agent status events).
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
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.events) { event in
                        eventRow(event)
                        Rectangle()
                            .fill(MonolithTheme.Colors.borderSoft)
                            .frame(height: 1)
                            .padding(.leading, MonolithTheme.Spacing.lg + 32 + MonolithTheme.Spacing.md)
                    }
                }
                .padding(.top, MonolithTheme.Spacing.sm)
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
        .task {
            if viewModel.events.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: header
    private var header: some View {
        HStack(spacing: MonolithTheme.Spacing.sm) {
            Text("ACTIVITY")
                .font(MonolithFont.mono(size: 12, weight: .bold))
                .tracking(0.72)
                .foregroundColor(MonolithTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle().fill(MonolithTheme.Colors.bgElevated).frame(height: 1),
            alignment: .bottom
        )
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
                HStack(spacing: 6) {
                    Text(event.actor.displayName)
                        .font(event.actor.isAgent
                              ? MonolithFont.mono(size: 14, weight: .medium)
                              : MonolithFont.sans(size: 15, weight: .medium))
                        .foregroundColor(MonolithTheme.Colors.textPrimary)
                    Text(verb(for: event.kind))
                        .font(MonolithFont.mono(size: 10, weight: .medium))
                        .tracking(0.6)
                        .foregroundColor(MonolithTheme.Colors.textTertiary)
                    Spacer()
                    Text(timeLabel(event.timestamp))
                        .font(MonolithFont.mono(size: 10))
                        .foregroundColor(MonolithTheme.Colors.textMuted)
                }
                Text(event.summary)
                    .font(MonolithFont.sans(size: 14))
                    .foregroundColor(MonolithTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                Text(event.target)
                    .font(MonolithFont.mono(size: 11))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
            }
        }
        .padding(.horizontal, MonolithTheme.Spacing.lg)
        .padding(.vertical, MonolithTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func actorAvatar(_ actor: Member) -> some View {
        switch actor.kind {
        case .human(let h): HumanAvatar(human: h, size: .lg)
        case .agent(let a): AgentAvatar(agent: a, size: .lg)
        }
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
    private func verb(for kind: ActivityKind) -> String {
        switch kind {
        case .mention:        return "MENTIONED YOU"
        case .flag:           return "FLAGGED"
        case .threadReply:    return "REPLIED"
        case .agentCompleted: return "COMPLETED"
        case .agentStatus:    return "STATUS"
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview("ActivityTabView") {
    ActivityTabView(activityRepo: MockActivityRepository())
}
