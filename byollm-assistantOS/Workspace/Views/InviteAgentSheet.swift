//
//  InviteAgentSheet.swift
//  Workspace
//
//  Screen 06 — invite a new agent: pick a template, instance size, and
//  initial channel membership.
//

import SwiftUI

@MainActor
final class InviteAgentViewModel: ObservableObject {
    @Published var template: String = "researcher"
    @Published var instanceSize: String = "m8g.medium"
    @Published var selectedChannelIDs: Set<ChannelID>
    @Published var name: String = ""
    @Published var submitting: Bool = false
    @Published var errorMessage: String?

    var channels: [Channel]
    private let agentRepo: AgentRepository

    init(
        channels: [Channel],
        defaultChannelIDs: Set<ChannelID>,
        agentRepo: AgentRepository
    ) {
        self.channels = channels
        self.selectedChannelIDs = defaultChannelIDs
        self.agentRepo = agentRepo
    }

    func submit() async -> Agent? {
        submitting = true
        defer { submitting = false }
        let spec = AgentInviteSpec(
            template: template,
            instanceSize: instanceSize,
            channelIDs: Array(selectedChannelIDs),
            name: name.isEmpty ? nil : name
        )
        do {
            return try await agentRepo.invite(spec)
        } catch {
            errorMessage = "\(error)"
            return nil
        }
    }
}

struct InviteAgentSheet: View {
    @StateObject private var viewModel: InviteAgentViewModel
    var onClose: (() -> Void)?
    var onInvited: ((Agent) -> Void)?

    init(
        channels: [Channel] = MockChannels.all,
        defaultChannelIDs: Set<ChannelID> = [
            MockChannels.general.id,
            MockChannels.clientOps.id
        ],
        agentRepo: AgentRepository,
        onClose: (() -> Void)? = nil,
        onInvited: ((Agent) -> Void)? = nil
    ) {
        self._viewModel = StateObject(
            wrappedValue: InviteAgentViewModel(
                channels: channels,
                defaultChannelIDs: defaultChannelIDs,
                agentRepo: agentRepo
            )
        )
        self.onClose = onClose
        self.onInvited = onInvited
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: MonolithTheme.Spacing.xl) {
                    section("TEMPLATE") { templatesGrid }
                    section("SIZE")     { sizesList }
                    section("CHANNELS") { channelsList }
                    section("NAME (optional)") { nameField }
                    submitButton
                }
                .padding(MonolithTheme.Spacing.lg)
            }
        }
        .background(MonolithTheme.Colors.bgBase.ignoresSafeArea())
    }

    // MARK: header
    private var header: some View {
        HStack {
            Text("INVITE AGENT")
                .font(MonolithFont.mono(size: 11, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
            Button(action: { onClose?() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.leading, MonolithTheme.Spacing.lg)
        .padding(.trailing, MonolithTheme.Spacing.xs)
        .frame(minHeight: 44)
        .background(MonolithTheme.Colors.bgSurface)
        .overlay(
            Rectangle().fill(MonolithTheme.Colors.borderSoft).frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: section wrapper
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: MonolithTheme.Spacing.sm) {
            Text(title)
                .font(MonolithFont.mono(size: 10, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            content()
        }
    }

    // MARK: templates
    private let templates = ["researcher", "engineer", "operator", "blank"]
    private var templatesGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
            spacing: 8
        ) {
            ForEach(templates, id: \.self) { t in
                let selected = (viewModel.template == t)
                Button(action: { viewModel.template = t }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t)
                            .font(MonolithFont.mono(size: 13, weight: .medium))
                            .foregroundColor(MonolithTheme.Colors.textPrimary)
                        Text(templateSubtitle(t))
                            .font(MonolithFont.mono(size: 10))
                            .foregroundColor(MonolithTheme.Colors.textTertiary)
                    }
                    .padding(MonolithTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selected
                                ? MonolithTheme.Colors.bgHover
                                : MonolithTheme.Colors.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                            .stroke(selected
                                    ? MonolithTheme.Colors.accent
                                    : MonolithTheme.Colors.borderSoft,
                                    lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func templateSubtitle(_ t: String) -> String {
        switch t {
        case "researcher": return "reads, summarizes, investigates"
        case "engineer":   return "builds, ships, reviews code"
        case "operator":   return "triages, coordinates, reports"
        default:           return "starts empty; you scope it"
        }
    }

    // MARK: sizes
    private struct SizeOption: Identifiable {
        let id: String
        let label: String
        let spec: String
        let price: String
    }
    private let sizes: [SizeOption] = [
        .init(id: "m8g.small",  label: "m8g.small",  spec: "1 vcpu · 2 gb", price: "$18/mo"),
        .init(id: "m8g.medium", label: "m8g.medium", spec: "2 vcpu · 4 gb", price: "$36/mo"),
        .init(id: "m8g.large",  label: "m8g.large",  spec: "4 vcpu · 8 gb", price: "$72/mo"),
    ]

    private var sizesList: some View {
        VStack(spacing: 0) {
            ForEach(sizes) { s in
                let selected = (viewModel.instanceSize == s.id)
                Button(action: { viewModel.instanceSize = s.id }) {
                    HStack(spacing: MonolithTheme.Spacing.md) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 16))
                            .foregroundColor(selected
                                             ? MonolithTheme.Colors.accent
                                             : MonolithTheme.Colors.textMuted)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.label)
                                .font(MonolithFont.mono(size: 13, weight: .medium))
                                .foregroundColor(MonolithTheme.Colors.textPrimary)
                            Text(s.spec)
                                .font(MonolithFont.mono(size: 10))
                                .foregroundColor(MonolithTheme.Colors.textTertiary)
                        }
                        Spacer()
                        Text(s.price)
                            .font(MonolithFont.mono(size: 12))
                            .foregroundColor(MonolithTheme.Colors.textSecondary)
                    }
                    .padding(MonolithTheme.Spacing.md)
                    .background(selected
                                ? MonolithTheme.Colors.bgHover
                                : MonolithTheme.Colors.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                            .stroke(selected
                                    ? MonolithTheme.Colors.accent
                                    : MonolithTheme.Colors.borderSoft,
                                    lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: channels
    private var channelsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.channels) { c in
                let selected = viewModel.selectedChannelIDs.contains(c.id)
                Button(action: {
                    if selected { viewModel.selectedChannelIDs.remove(c.id) }
                    else { viewModel.selectedChannelIDs.insert(c.id) }
                }) {
                    HStack(spacing: MonolithTheme.Spacing.md) {
                        Image(systemName: selected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(selected
                                             ? MonolithTheme.Colors.accent
                                             : MonolithTheme.Colors.textMuted)
                        Text("#\(c.name)")
                            .font(MonolithFont.sans(size: 14))
                            .foregroundColor(MonolithTheme.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, MonolithTheme.Spacing.md)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(MonolithTheme.Colors.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
    }

    // MARK: name
    private var nameField: some View {
        TextField("leave blank to auto-generate", text: $viewModel.name)
            .font(MonolithFont.mono(size: 13))
            .foregroundColor(MonolithTheme.Colors.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(MonolithTheme.Spacing.md)
            .background(MonolithTheme.Colors.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: MonolithTheme.Radius.md)
                    .stroke(MonolithTheme.Colors.borderSoft, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
    }

    // MARK: submit
    private var submitButton: some View {
        Button(action: {
            Task {
                if let agent = await viewModel.submit() {
                    onInvited?(agent)
                }
            }
        }) {
            HStack {
                Spacer()
                Text(viewModel.submitting ? "inviting…" : "invite agent")
                    .font(MonolithFont.mono(size: 14, weight: .medium))
                    .foregroundColor(MonolithTheme.Colors.textPrimary)
                Spacer()
            }
            .frame(minHeight: 44)
            .background(MonolithTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: MonolithTheme.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.submitting)
    }
}

#Preview("InviteAgentSheet") {
    InviteAgentSheet(agentRepo: MockAgentRepository())
}
