//
//  ModelSheet.swift
//  byollm-assistantOS
//
//  Bottom-sheet model picker.
//

import SwiftUI

struct ModelSheet: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(ChatTheme.line2(mode)).frame(width: 36, height: 4)
                .padding(.bottom, 14)

            HStack(alignment: .firstTextBaseline) {
                Text("Choose a model")
                    .font(ChatFont.sans(17, weight: .bold))
                    .tracking(-0.4)
                    .foregroundColor(ChatTheme.text(mode))
                Spacer()
                HStack(spacing: 6) {
                    StatusDot(status: store.activeServer?.status ?? .unknown, size: 7)
                    Text(store.activeServer?.status.label ?? "No server")
                        .font(ChatFont.sans(11.5, weight: .semibold))
                        .foregroundColor(ChatTheme.sub(mode))
                }
            }
            Text("Available on \(store.activeServer?.name ?? "your local server")")
                .font(ChatFont.sans(12.5))
                .foregroundColor(ChatTheme.sub(mode))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            Group {
                switch store.modelLoadState {
                case .idle:
                    ModelLoadMessage(
                        icon: "server.rack",
                        title: store.activeServer == nil ? "No server selected" : "Models not loaded",
                        detail: store.activeServer == nil
                            ? "Add and select a server in Settings to choose a model."
                            : "Load the models available on this server.",
                        retryLabel: store.activeServer == nil ? nil : "Load models",
                        mode: mode,
                        onRetry: store.refreshModels
                    )
                case .loading:
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(ChatTheme.text(mode))
                        Text("Loading models…")
                            .font(ChatFont.sans(13, weight: .semibold))
                            .foregroundColor(ChatTheme.sub(mode))
                    }
                    .frame(maxWidth: .infinity, minHeight: 128)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Loading models")
                case .empty:
                    ModelLoadMessage(
                        icon: "square.stack.3d.up.slash",
                        title: "No models available",
                        detail: "The server responded, but did not report any models.",
                        retryLabel: "Retry",
                        mode: mode,
                        onRetry: store.refreshModels
                    )
                case .failed(let message):
                    ModelLoadMessage(
                        icon: "exclamationmark.triangle",
                        title: "Couldn’t load models",
                        detail: message,
                        retryLabel: "Retry",
                        mode: mode,
                        onRetry: store.refreshModels
                    )
                case .loaded:
                    if store.selectableModels.isEmpty {
                        ModelLoadMessage(
                            icon: "square.stack.3d.up.slash",
                            title: "No models available",
                            detail: "Refresh the model list from this server.",
                            retryLabel: "Retry",
                            mode: mode,
                            onRetry: store.refreshModels
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(store.selectableModels) { model in
                                    modelRow(model)
                                }
                            }
                        }
                        .frame(maxHeight: 320)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background(ChatTheme.bg(mode))
        .clipShape(RoundedCorner(radius: 22, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: -8)
    }

    private func modelRow(_ model: ChatModel) -> some View {
        let isSelected = model.name == store.activeModel

        return Button(action: { store.pickModel(model.name) }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(ChatFont.sans(14, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                    Text(model.meta)
                        .font(ChatFont.sans(11.5))
                        .foregroundColor(ChatTheme.sub(mode))
                }
                Spacer()
                if isSelected {
                    Image(systemName: ChatIcon.check)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ChatTheme.online)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 14)
            .background(ChatTheme.card(mode))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        isSelected ? ChatTheme.text(mode) : ChatTheme.line2(mode),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.touch)
        .accessibilityLabel(model.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ModelLoadMessage: View {
    let icon: String
    let title: String
    let detail: String
    let retryLabel: String?
    let mode: ChatTheme.Mode
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ChatTheme.sub(mode))

            VStack(spacing: 4) {
                Text(title)
                    .font(ChatFont.sans(14, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                Text(detail)
                    .font(ChatFont.sans(12.5))
                    .foregroundColor(ChatTheme.sub(mode))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let retryLabel {
                Button(action: onRetry) {
                    Text(retryLabel)
                        .font(ChatFont.sans(12.5, weight: .bold))
                        .foregroundColor(ChatTheme.text(mode))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
                }
                .buttonStyle(.touch)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }
}
