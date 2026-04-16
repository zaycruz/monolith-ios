//
//  BlinkingCursor.swift
//  Workspace
//
//  2pt × 18pt snow rectangle that pulses on/off. Used inside the launch
//  agent sheet's name field, which has an `agent /` prefix and shows the
//  cursor even when unfocused to reinforce that it's ready for typing.
//

import SwiftUI

struct BlinkingCursor: View {
    let width: CGFloat
    let height: CGFloat

    @State private var visible: Bool = true

    init(width: CGFloat = 2, height: CGFloat = 18) {
        self.width = width
        self.height = height
    }

    var body: some View {
        Rectangle()
            .fill(MonolithTheme.Colors.textPrimary)
            .frame(width: width, height: height)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("BlinkingCursor") {
    HStack(spacing: 4) {
        Text("agent /")
            .font(MonolithFont.mono(size: 14, weight: .medium))
            .foregroundColor(MonolithTheme.Colors.textPrimary)
        BlinkingCursor()
    }
    .padding()
    .background(MonolithTheme.Colors.bgBase)
}
