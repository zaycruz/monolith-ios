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
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var speechDraft = ""

    private var canSend: Bool {
        !store.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !store.streaming
            && store.isChatReady
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.reasoningOpen {
                ReasoningEffortControl(store: store, mode: mode)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let attachment = store.attach {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ChatTheme.text(mode))
                        Text(attachment)
                            .font(ChatFont.sans(12, weight: .semibold))
                            .foregroundColor(ChatTheme.text(mode))
                            .lineLimit(1)
                        Button(action: { store.clearAttach() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ChatTheme.sub(mode))
                        }
                        .buttonStyle(.touch)
                        .accessibilityLabel("Remove \(attachment)")
                    }
                    .padding(.leading, 12)
                    .background(ChatTheme.surface(mode))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ChatTheme.line2(mode), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Button(action: { store.toggleAttach() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(ChatTheme.text(mode).opacity(0.78))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.touch)
                .accessibilityLabel("Add attachment")

                TextField("Ask anything", text: $store.input, axis: .vertical)
                    .font(ChatFont.sans(15))
                    .foregroundColor(ChatTheme.text(mode))
                    .focused($focused)
                    .lineLimit(1...6)
                    .submitLabel(.send)
                    .padding(.vertical, 11)
                    .frame(minHeight: 44)
                    .onSubmit {
                        if canSend {
                            sendMessage()
                        }
                    }

                Button(action: toggleSpeechRecognition) {
                    Image(systemName: speechRecognizer.isRecording ? "waveform" : "mic")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(speechRecognizer.isRecording ? Color.red : ChatTheme.text(mode).opacity(0.72))
                        .frame(width: 38, height: 44)
                }
                .buttonStyle(.touch)
                .disabled(speechRecognizer.isStarting)
                .accessibilityLabel(speechRecognizer.isRecording ? "Stop speech to text" : "Start speech to text")

                if store.streaming {
                    Button(action: { store.stop() }) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ChatTheme.bg(mode))
                            .frame(width: 11, height: 11)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(ChatTheme.text(mode)))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.touch)
                    .accessibilityLabel("Stop response")
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(ChatTheme.bg(mode))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(store.sendBg))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.touch)
                    .disabled(!canSend)
                    .accessibilityLabel("Send message")
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 5)
            .padding(.vertical, 5)
            .frame(minHeight: 56)
            .background(ChatTheme.surface(mode))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(ChatTheme.line2(mode), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Menu {
                    ForEach(store.harnesses) { harness in
                        Button(harness.name) { store.selectRuntime(harness.runtime) }
                            .disabled(store.activeChat != nil || !harness.available)
                    }
                } label: {
                    Text(store.currentRuntimeName)
                        .font(ChatFont.sans(11, weight: .semibold))
                }
                .disabled(store.activeChat != nil || store.streaming)
                .accessibilityHint(store.activeChat == nil ? "Choose the runtime for this new chat" : "Runtime is pinned for this chat")

                Text("·")

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) { store.reasoningOpen.toggle() }
                }) {
                    Text(store.reasoningEffort.title)
                        .font(ChatFont.sans(11, weight: .semibold))
                }
                .buttonStyle(.touch)
                .accessibilityLabel("Reasoning effort \(store.reasoningEffort.title)")

                Text("· \(store.activeServer?.name ?? "No server") · \(store.activeModelShort)")
                    .lineLimit(1)
            }
            .font(ChatFont.sans(11))
            .foregroundColor(ChatTheme.sub(mode))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 2)

            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(ChatFont.sans(11, weight: .semibold))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.top, 3)
                    .accessibilityLabel("Speech to text error: \(error)")
            }
        }
        .padding(.bottom, 8)
        .onChange(of: speechRecognizer.transcript) { _, transcript in
            store.input = SpeechTranscriptComposer.compose(draft: speechDraft, transcript: transcript)
        }
        .onChange(of: store.drawer) { _, isOpen in
            if isOpen { cancelSpeechRecognition() }
        }
        .onChange(of: store.modelSheet) { _, isOpen in
            if isOpen { cancelSpeechRecognition() }
        }
        .onChange(of: store.newProjOpen) { _, isOpen in
            if isOpen { cancelSpeechRecognition() }
        }
        .onDisappear { speechRecognizer.stopRecording() }
    }

    private func sendMessage() {
        cancelSpeechRecognition()
        focused = false
        store.send(store.input)
    }

    private func cancelSpeechRecognition() {
        if speechRecognizer.isRecording || speechRecognizer.isStarting {
            speechRecognizer.stopRecording()
        }
    }

    private func toggleSpeechRecognition() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            focused = true
            return
        }
        speechDraft = store.input
        focused = false
        dismissAppKeyboard()
        speechRecognizer.startRecording()
    }
}

struct ReasoningEffortControl: View {
    @ObservedObject var store: AppStore
    var mode: ChatTheme.Mode

    private var selectedIndex: Int {
        ReasoningEffort.allCases.firstIndex(of: store.reasoningEffort) ?? 2
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("\(store.activeModelShort) \(store.reasoningEffort.title)")
                .font(ChatFont.sans(15, weight: .bold))
                .foregroundColor(ChatTheme.text(mode))

            GeometryReader { proxy in
                let count = CGFloat(ReasoningEffort.allCases.count - 1)
                let usableWidth = max(proxy.size.width - 40, 1)
                let x = 20 + usableWidth * CGFloat(selectedIndex) / count

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ChatTheme.card(mode))
                        .overlay(Capsule().stroke(ChatTheme.line2(mode), lineWidth: 1))

                    ForEach(Array(ReasoningEffort.allCases.enumerated()), id: \.element.id) { index, _ in
                        Circle()
                            .fill(index <= selectedIndex ? ChatTheme.text(mode) : ChatTheme.sub(mode).opacity(0.55))
                            .frame(width: 8, height: 8)
                            .position(x: 20 + usableWidth * CGFloat(index) / count, y: 28)
                    }

                    Circle()
                        .fill(ChatTheme.bg(mode))
                        .overlay(Circle().stroke(ChatTheme.text(mode), lineWidth: 3))
                        .frame(width: 42, height: 42)
                        .position(x: x, y: 28)
                }
                .contentShape(Capsule())
                .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                            let ratio = min(max((value.location.x - 20) / usableWidth, 0), 1)
                            let index = Int((ratio * count).rounded())
                        store.reasoningEffort = ReasoningEffort.allCases[index]
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.18)) { store.dismissReasoning() }
                    }
            )
            }
            .frame(height: 56)
            .accessibilityElement()
            .accessibilityLabel("Reasoning effort")
            .accessibilityValue(store.reasoningEffort.title)
            .accessibilityAdjustableAction { direction in
                var index = selectedIndex
                index += direction == .increment ? 1 : -1
                index = min(max(index, 0), ReasoningEffort.allCases.count - 1)
                store.reasoningEffort = ReasoningEffort.allCases[index]
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(mode == .dark ? 0.22 : 0.13),
                            Color.purple.opacity(mode == .dark ? 0.28 : 0.16),
                            Color.pink.opacity(mode == .dark ? 0.20 : 0.12),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 16)
        }
        .modifier(ReasoningGlassSurface(mode: mode))
        .shadow(color: Color.black.opacity(mode == .dark ? 0.32 : 0.14), radius: 22, y: -6)
    }
}

private struct ReasoningGlassSurface: ViewModifier {
    let mode: ChatTheme.Mode

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(Color.purple.opacity(mode == .dark ? 0.14 : 0.08)).interactive(),
                    in: .rect(cornerRadius: 24)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(mode == .dark ? 0.18 : 0.5), lineWidth: 1)
                )
        }
    }
}
