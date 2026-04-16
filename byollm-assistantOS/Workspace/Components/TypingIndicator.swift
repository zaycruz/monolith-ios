//
//  TypingIndicator.swift
//  Workspace
//
//  "dispatch is thinking" row rendered below the messages list while an
//  agent is composing. 3 ash dots pulsing. Kept intentionally small.
//
//  NOTE: named `WorkspaceTypingIndicator` to avoid colliding with the
//  pre-existing `TypingIndicator` in ChatView (legacy BYOLLM screen).
//

import SwiftUI

struct WorkspaceTypingIndicator: View {
    let name: String
    let isAgent: Bool

    init(name: String, isAgent: Bool = true) {
        self.name = name
        self.isAgent = isAgent
    }

    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            dots
            Text("\(name) is thinking")
                .font(MonolithFont.sans(size: 12))
                .foregroundColor(MonolithTheme.Colors.textTertiary)
            Spacer()
        }
        .padding(.horizontal, MonolithTheme.Spacing.xl)
        .padding(.vertical, MonolithTheme.Spacing.xs)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(MonolithTheme.Colors.textTertiary)
                    .frame(width: 4, height: 4)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
    }
}

#Preview("WorkspaceTypingIndicator") {
    WorkspaceTypingIndicator(name: "dispatch")
        .background(MonolithTheme.Colors.bgBase)
}
