//
//  ChatComponents.swift
//  byollm-assistantOS
//
//  Shared building blocks: the Monolith emblem mark, SF-symbol icon
//  helpers matching the design's icon set, and the assistant avatar.
//

import SwiftUI

// MARK: - Monolith emblem (4-segment geometric mark)
/// Four angular segments arranged around a central void, matching the
/// brand emblem. Drawn natively — no SVG parsing.
struct LogoMark: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        // One segment: a right-pointing chevron/arrow wedge.
        // Rotated to 4 orientations (0°, 90°, 180°, 270°).
        for i in 0..<4 {
            let seg = wedge(center: .zero, r: r)
            let angle = Angle(degrees: Double(i) * 90)
            let t = CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: CGFloat(angle.radians))
            p.addPath(seg.applying(t))
        }
        return p
    }

    /// A single angular segment pointing +x, centred at `center`.
    private func wedge(center: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        let outer = r
        let inner = r * 0.42
        let half = r * 0.52
        p.move(to: CGPoint(x: center.x + inner, y: center.y - half))
        p.addLine(to: CGPoint(x: center.x + outer, y: center.y))
        p.addLine(to: CGPoint(x: center.x + inner, y: center.y + half))
        p.addLine(to: CGPoint(x: center.x + inner * 0.4, y: center.y + half * 0.4))
        p.addLine(to: CGPoint(x: center.x + inner * 0.4, y: center.y - half * 0.4))
        p.closeSubpath()
        return p
    }
}

// MARK: - Icon helper
/// SF Symbol names matching the design's icon set.
enum ChatIcon {
    static let new = "square.and.pencil"
    static let search = "magnifyingglass"
    static let chat = "bubble.left"
    static let files = "folder"
    static let settings = "gearshape"
    static let upload = "square.and.arrow.up"
    static let plus = "plus"
    static let chevronRight = "chevron.right"
    static let chevronDown = "chevron.down"
    static let back = "chevron.left"
    static let check = "checkmark"
    static let github = "chevron.left.forwardslash.chevron.right"
}

// MARK: - Assistant avatar (emblem in rounded square)
struct AssistantAvatar: View {
    var mode: ChatTheme.Mode
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(ChatTheme.surface(mode))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChatTheme.line(mode), lineWidth: 1))
            LogoMark()
                .fill(ChatTheme.text(mode))
                .frame(width: size * 0.46, height: size * 0.46)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Status dot
struct StatusDot: View {
    var status: ServerStatus
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.dotColor)
            .frame(width: size, height: size)
            .modifier(PulseModifier(active: status == .testing))
    }
}

struct PulseModifier: ViewModifier {
    var active: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .opacity(active ? (pulse ? 0.35 : 1) : 1)
            .animation(active ? .easeInOut(duration: 0.5).repeatForever() : .default, value: pulse)
            .onAppear { pulse = active }
    }
}
