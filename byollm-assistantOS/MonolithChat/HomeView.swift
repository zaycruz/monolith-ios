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
        "Draft an agent prompt for invoice triage",
        "Write a vLLM launch command for a 70B model",
        "Summarize a document from my files"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(store: store, mode: mode, center: nil)
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatusDot(status: store.activeServer?.status ?? .unknown)
                    Text(store.activeServerStatusLine)
                        .font(ChatFont.sans(12.5, weight: .semibold))
                        .foregroundColor(ChatTheme.sub(mode))
                }
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            Spacer()
            VStack(spacing: 8) {
                ForEach(prompts, id: \.self) { p in
                    Button {
                        store.usePrompt(p)
                    } label: {
                        Text(p)
                            .font(ChatFont.sans(14, weight: .semibold))
                            .foregroundColor(ChatTheme.text(mode))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(ChatTheme.card(mode))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
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
            Button(action: { store.openDrawer() }) {
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(ChatTheme.text(mode)).frame(width: 18, height: 2)
                    RoundedRectangle(cornerRadius: 2).fill(ChatTheme.text(mode)).frame(width: 12, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 44, height: 44)
                .padding(.leading, 6)
            }
            .buttonStyle(.plain)

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
                    .padding(.trailing, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .overlay(
            showBorder ? Rectangle().frame(height: 1).foregroundColor(ChatTheme.line(mode)).frame(maxHeight: .infinity, alignment: .bottom) : nil
        )
    }
}
