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
                Text("Models")
                    .font(ChatFont.sans(16, weight: .bold))
                    .tracking(-0.4)
                    .foregroundColor(ChatTheme.text(mode))
                Spacer()
                Text("GET /v1/models")
                    .font(ChatFont.mono(11))
                    .foregroundColor(ChatTheme.sub(mode))
            }
            Text("Loaded on \(store.activeServer?.name ?? "server")")
                .font(ChatFont.sans(12))
                .foregroundColor(ChatTheme.sub(mode))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 12)

            VStack(spacing: 6) {
                ForEach(store.models) { mo in
                    Button(action: { store.pickModel(mo.name) }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mo.name)
                                    .font(ChatFont.sans(14, weight: .bold))
                                    .foregroundColor(ChatTheme.text(mode))
                                Text(mo.meta)
                                    .font(ChatFont.sans(11.5))
                                    .foregroundColor(ChatTheme.sub(mode))
                            }
                            Spacer()
                            if mo.name == store.activeModel {
                                Image(systemName: ChatIcon.check)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(ChatTheme.online)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(ChatTheme.card(mode))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(mo.name == store.activeModel ? ChatTheme.text(mode) : ChatTheme.line2(mode), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
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
}
