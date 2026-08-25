//
//  HomeView.swift
//  byollm-assistantOS
//
//  Home screen — server status, headline, subtitle, prompt pills.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    private let prompts = [
        (icon: "wand.and.stars", text: "Draft an agent prompt for invoice triage"),
        (icon: "terminal", text: "Write a vLLM launch command for a 70B model"),
        (icon: "doc.text.magnifyingglass", text: "Summarize a document from my files")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(
                store: store,
                mode: mode,
                center: AnyView(ModelSelectorButton(store: store, mode: mode))
            )
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatusDot(status: store.activeServer?.status ?? .unknown)
                    Text(store.activeServerStatusLine)
                        .font(ChatFont.sans(12.5, weight: .semibold))
                        .foregroundColor(ChatTheme.sub(mode))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .monolithGlass(mode: mode, cornerRadius: 16)
                Text("What should we work on?")
                    .font(ChatFont.sans(34, weight: .bold))
                    .tracking(-0.8)
                    .lineSpacing(4)
                    .foregroundColor(ChatTheme.text(mode))
                Text("Running privately on your own hardware. Nothing leaves your network.")
                    .font(ChatFont.sans(14))
                    .lineSpacing(5)
                    .foregroundColor(ChatTheme.sub(mode))
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 8) {
                ForEach(Array(prompts.enumerated()), id: \.offset) { _, prompt in
                    Button {
                        store.usePrompt(prompt.text)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: prompt.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(ChatTheme.sub(mode))
                                .frame(width: 24)
                            Text(prompt.text)
                                .font(ChatFont.sans(14, weight: .semibold))
                                .foregroundColor(ChatTheme.text(mode))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ChatTheme.sub(mode).opacity(0.78))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .monolithGlass(mode: mode, cornerRadius: 18, interactive: true)
                    }
                    .buttonStyle(.touch)
                    .disabled(!store.isChatReady)
                    .opacity(store.isChatReady ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .frame(maxWidth: 720)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.dismissReasoning()
            dismissAppKeyboard()
        }
    }
}

// MARK: - Shared top bar (drawer + new chat)
struct ChatTopBar: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode
    var center: AnyView?
    var showBorder: Bool = false

    var body: some View {
        HStack {
            Button(action: {
                store.openDrawer()
            }) {
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(ChatTheme.text(mode)).frame(width: 18, height: 2)
                    RoundedRectangle(cornerRadius: 2).fill(ChatTheme.text(mode)).frame(width: 12, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.touch)
            .monolithGlass(mode: mode, cornerRadius: 22, interactive: true)
            .accessibilityLabel("Open navigation")

            Spacer()

            if let center = center {
                center
            }

            Spacer()

            Button(action: { store.newChat() }) {
                Image(systemName: ChatIcon.new)
                    .font(.system(size: 20))
                    .foregroundColor(ChatTheme.text(mode))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.touch)
            .monolithGlass(mode: mode, cornerRadius: 22, interactive: true)
            .accessibilityLabel("New chat")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(
            showBorder
                ? Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(ChatTheme.line(mode))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                : nil
        )
    }
}
