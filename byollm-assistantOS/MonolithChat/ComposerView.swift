//
//  ComposerView.swift
//  byollm-assistantOS
//
//  Bottom composer — attach chip, rounded input bar, send/stop button,
//  privacy footer.
//

import SwiftUI

struct ComposerView: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let attach = store.attach {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: ChatIcon.upload)
                            .font(.system(size: 14))
                            .foregroundColor(ChatTheme.text(mode))
                        Text(attach)
                            .font(ChatFont.sans(12, weight: .semibold))
                            .foregroundColor(ChatTheme.text(mode))
                        Button(action: { store.clearAttach() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .foregroundColor(ChatTheme.sub(mode))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(ChatTheme.surface(mode))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChatTheme.line2(mode), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: { store.toggleAttach() }) {
                    Image(systemName: ChatIcon.upload)
                        .font(.system(size: 19))
                        .foregroundColor(ChatTheme.text(mode).opacity(0.7))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                TextField("Message Monolith…", text: $store.input, axis: .vertical)
                    .font(ChatFont.sans(14.5))
                    .foregroundColor(ChatTheme.text(mode))
                    .focused($focused)
                    .padding(.vertical, 9)
                    .onSubmit { store.send(store.input) }

                if store.streaming {
                    Button(action: { store.stop() }) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ChatTheme.bg(mode))
                            .frame(width: 11, height: 11)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(ChatTheme.text(mode)))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { store.send(store.input) }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(ChatTheme.bg(mode))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(store.sendBg))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(ChatTheme.surface(mode))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(ChatTheme.line2(mode), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 12)

            Text("Local model · \(store.activeModelShort) · no data leaves your device")
                .font(ChatFont.sans(10.5))
                .foregroundColor(ChatTheme.sub(mode))
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 8)
    }
}
