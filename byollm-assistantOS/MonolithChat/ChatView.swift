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
            ChatTopBar(
                store: store,
                mode: mode,
                center: AnyView(ModelSelectorButton(store: store, mode: mode)),
                showBorder: true
            )
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
                                .font(ChatFont.mono(.caption))
                                .foregroundColor(ChatTheme.sub(mode))
                                .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    store.dismissReasoning()
                    dismissAppKeyboard()
                }
                .onChange(of: store.tok) { _, _ in
                    if let last = store.activeChat?.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
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
                    .font(ChatFont.sans(.callout))
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
                    ForEach(Array(msg.blocks.enumerated()), id: \.offset) { bi, block in
                        switch block {
                        case .text(let text):
                            MarkdownText(content: text)
                                .font(ChatFont.sans(.body))
                                .lineSpacing(6)
                                .foregroundColor(ChatTheme.text(mode))
                                .textSelection(.enabled)
                                .overlay(
                                    streaming
                                        && msg.streaming
                                        && bi == msg.blocks.count - 1
                                        ? AnyView(BlinkCursor(mode: mode))
                                        : AnyView(EmptyView()),
                                    alignment: .bottomTrailing
                                )
                        case .code(let lang, let t):
                            CodeBlockView(lang: lang, code: t, mode: mode)
                        case .tool(let tool):
                            ToolCallRow(tool: tool, mode: mode)
                        }
                    }
                    if isLast && !streaming && !msg.blocks.isEmpty {
                        Button(action: { store.regen() }) {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                                .font(ChatFont.sans(.footnote, weight: .semibold))
                                .foregroundColor(ChatTheme.sub(mode))
                                .padding(.horizontal, 12)
                                .overlay(
                                    Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.touch)
                        .accessibilityHint("Generates a new response to the last message")
                    }
                }
            }
        }
    }
}

struct ToolCallRow: View {
    let tool: ToolCallBlock
    let mode: ChatTheme.Mode
    @State private var expanded = false

    private var icon: String {
        switch tool.status {
        case .running: return "gearshape.2"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    private var statusLabel: String {
        switch tool.status {
        case .running: return "Running"
        case .succeeded: return "Done"
        case .failed: return "Failed"
        case .cancelled: return "Stopped"
        }
    }

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.16)) { expanded.toggle() } }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .symbolEffect(.rotate, options: .repeating, isActive: tool.status == .running)
                    Text(tool.name)
                        .font(ChatFont.sans(.subheadline, weight: .semibold))
                    Spacer()
                    Text(statusLabel)
                        .font(ChatFont.sans(.caption, weight: .semibold))
                        .foregroundColor(ChatTheme.sub(mode))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ChatTheme.sub(mode))
                }

                if expanded {
                    if !tool.input.isEmpty {
                        Text(tool.input)
                            .font(ChatFont.mono(.caption))
                            .foregroundColor(ChatTheme.sub(mode))
                            .lineLimit(8)
                    }
                    if !tool.output.isEmpty {
                        Text(tool.output)
                            .font(ChatFont.mono(.caption))
                            .foregroundColor(ChatTheme.text(mode))
                            .lineLimit(12)
                    }
                }
            }
            .foregroundColor(ChatTheme.text(mode))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ChatTheme.card(mode))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(ChatTheme.line2(mode), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.touch)
        .accessibilityLabel("\(tool.name) tool call, \(statusLabel)")
        .accessibilityHint("Shows tool input and output")
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
                    .font(ChatFont.sans(.caption2, weight: .bold))
                    .tracking(1)
                    .foregroundColor(ChatTheme.sub(.dark))
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = code
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copied = false
                    }
                }) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(ChatFont.sans(.caption2, weight: .semibold))
                        .foregroundColor(ChatTheme.sub(.dark))
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.touch)
                .accessibilityLabel(copied ? "Code copied" : "Copy code")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color.white.opacity(0.12)), alignment: .bottom)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(ChatFont.mono(.caption))
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
