//
//  ChatView.swift
//  byollm-assistantOS
//
//  Chat screen — model pill, message list (user bubbles, assistant
//  blocks with code + regenerate), streaming stats line.
//

import SwiftUI
import UIKit

struct ChatView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    var body: some View {
        VStack(spacing: 0) {
            ChatTopBar(store: store, mode: mode, center: AnyView(modelPill), showBorder: true)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if let chat = store.activeChat {
                            ForEach(Array(chat.messages.enumerated()), id: \.element.id) { idx, msg in
                                MessageRowView(msg: msg, mode: mode, isLast: idx == chat.messages.count - 1, streaming: store.streaming, store: store)
                                    .id(msg.id)
                            }
                        }
                        if store.streaming {
                            Text(store.statLine)
                                .font(ChatFont.mono(11))
                                .foregroundColor(ChatTheme.sub(mode))
                                .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                }
                .onChange(of: store.tok) { _, _ in
                    if let last = store.activeChat?.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var modelPill: some View {
        Button(action: { store.openSheet() }) {
            HStack(spacing: 7) {
                StatusDot(status: store.activeServer?.status ?? .unknown, size: 7)
                Text(store.activeModelShort)
                    .font(ChatFont.sans(12.5, weight: .bold))
                    .foregroundColor(ChatTheme.text(mode))
                Image(systemName: ChatIcon.chevronDown)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ChatTheme.sub(mode))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(ChatTheme.card(mode))
            .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message row
struct MessageRowView: View {
    var msg: ThreadMessage
    var mode: ChatTheme.Mode
    var isLast: Bool
    var streaming: Bool
    @ObservedObject var store: AppStore

    var body: some View {
        if msg.role == .user {
            HStack {
                Spacer()
                Text(msg.text)
                    .font(ChatFont.sans(14.5))
                    .lineSpacing(4)
                    .foregroundColor(ChatTheme.bubbletext(mode))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(ChatTheme.bubble(mode))
                    .clipShape(RoundedCorner(radius: 18, corners: [.topLeft, .topRight, .bottomLeft]))
                    .clipShape(RoundedCorner(radius: 4, corners: [.bottomRight]))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .trailing)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                AssistantAvatar(mode: mode)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(msg.blocks.enumerated()), id: \.element.id) { bi, block in
                        switch block {
                        case .text(let t):
                            Text(t)
                                .font(ChatFont.sans(14.5))
                                .lineSpacing(6)
                                .foregroundColor(ChatTheme.text(mode))
                                .overlay(streaming && msg.streaming && bi == msg.blocks.count - 1 ? AnyView(BlinkCursor(mode: mode)) : AnyView(EmptyView()), alignment: .bottomTrailing)
                        case .code(let lang, let t):
                            CodeBlockView(lang: lang, code: t, mode: mode)
                        }
                    }
                    if isLast && !streaming && !msg.blocks.isEmpty {
                        Button(action: { store.regen() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Regenerate")
                                    .font(ChatFont.sans(12, weight: .bold))
                            }
                            .foregroundColor(ChatTheme.sub(mode))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Code block
struct CodeBlockView: View {
    var lang: String
    var code: String
    var mode: ChatTheme.Mode
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(lang.uppercased())
                    .font(ChatFont.sans(11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(ChatTheme.sub(.dark))
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }) {
                    Text(copied ? "Copied" : "Copy")
                        .font(ChatFont.sans(11, weight: .semibold))
                        .foregroundColor(ChatTheme.sub(.dark))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.12)), alignment: .bottom)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(ChatFont.mono(12))
                    .lineSpacing(5)
                    .foregroundColor(ChatTheme.codetext(mode))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(ChatTheme.codebg(mode))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Blinking cursor
struct BlinkCursor: View {
    var mode: ChatTheme.Mode
    @State private var on = false

    var body: some View {
        Rectangle()
            .fill(ChatTheme.text(mode))
            .frame(width: 8, height: 15)
            .opacity(on ? 1 : 0)
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

// MARK: - Rounded corner helper
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
