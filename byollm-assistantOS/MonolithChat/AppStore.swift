//
//  AppStore.swift
//  byollm-assistantOS
//
//  Single observable store for the Monolith Chat app. Owns screen
//  routing, drawer/sheet state, chats, servers, models, connections,
//  and projects. Streams real responses from the active vLLM server
//  via NetworkManager.
//

import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {

    // MARK: - Screen routing

    enum Screen: Equatable {
        case home, chat, settings, connections, chats, projects, project
    }

    @Published var screen: Screen = .home
    @Published var drawer = false
    @Published var modelSheet = false
    @Published var addConnOpen = false
    @Published var newProjOpen = false

    @Published var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "mc.isDark") }
    }

    var mode: ChatTheme.Mode { isDark ? .dark : .light }

    // MARK: - Chats

    @Published var chats: [Chat] = []
    @Published var activeChatId: Int?
    @Published var chatQuery = ""
    private var nextChatId = 1

    // MARK: - Composer

    @Published var input = ""
    @Published var attach: String?
    @Published var streaming = false
    @Published var tok = 0

    // MARK: - Servers / models

    @Published var servers: [LLMServer] = []
    @Published var models: [ChatModel] = []
    @Published var activeModel = ""
    private var nextServerId = 1

    // MARK: - Connections

    @Published var connections: [AppConnection] = []

    // MARK: - Projects

    @Published var projects: [ChatProject] = []
    @Published var activeProjectId: Int?
    @Published var npName = ""
    @Published var npDesc = ""
    @Published var npRepo: String?
    @Published var repoPickerOpen = false
    private var nextProjectId = 1

    // MARK: - Add server form

    @Published var addOpen = false
    @Published var addName = ""
    @Published var addUrl = ""
    @Published var addStatus: AddStatus = .idle

    enum AddStatus: Equatable { case idle, testing, ok, fail }

    init() {
        self.isDark = UserDefaults.standard.bool(forKey: "mc.isDark")
        seed()
        loadServers()
    }

    // MARK: - Seed

    private func seed() {
        connections = [
            AppConnection(id: "slack", name: "Slack", desc: "Channels and messages", account: "monolith.slack.com", connected: true),
            AppConnection(id: "github", name: "GitHub", desc: "Repos, issues, pull requests", account: "@monolith", connected: true),
            AppConnection(id: "notion", name: "Notion", desc: "Pages and databases", account: "Monolith HQ", connected: false),
            AppConnection(id: "gmail", name: "Gmail", desc: "Read and draft email", account: "ops@monolith.ai", connected: false)
        ]
    }

    // MARK: - Server persistence

    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: "mc.servers"),
           let saved = try? JSONDecoder().decode([SavedServer].self, from: data), !saved.isEmpty {
            servers = saved.map { s in
                nextServerId = max(nextServerId, s.id + 1)
                return LLMServer(id: s.id, name: s.name, url: s.url, active: s.active, status: .unknown)
            }
        } else {
            // No hardcoded server — the user adds their own OpenAI-compatible
            // endpoint in Settings (persisted to UserDefaults, never the repo).
            servers = []
            nextServerId = 1
        }
        if !servers.contains(where: { $0.active }) && !servers.isEmpty {
            servers[0].active = true
        }
        refreshModels()
    }

    private func persistServers() {
        let saved = servers.map { SavedServer(id: $0.id, name: $0.name, url: $0.url, active: $0.active) }
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: "mc.servers")
        }
    }

    private struct SavedServer: Codable {
        let id: Int
        var name: String
        var url: String
        var active: Bool
    }

    var activeServer: LLMServer? {
        servers.first(where: { $0.active }) ?? servers.first
    }

    /// Base URL trimmed of a trailing "/v1" — NetworkManager appends paths.
    private var serverBase: String {
        var url = activeServer?.url ?? ""
        if url.hasSuffix("/v1") { url = String(url.dropLast(3)) }
        return url
    }

    // MARK: - Models

    func refreshModels() {
        let base = serverBase
        guard !base.isEmpty else { return }
        Task {
            if let list = try? await NetworkManager.shared.getModels(from: base), !list.isEmpty {
                self.models = list.map { ChatModel(name: $0, meta: "Loaded on server") }
                if self.activeModel.isEmpty || !list.contains(self.activeModel) {
                    self.activeModel = list[0]
                }
            }
        }
    }

    func pickModel(_ name: String) {
        activeModel = name
        modelSheet = false
    }

    // MARK: - Server actions

    func selectServer(_ id: Int) {
        servers = servers.map { var s = $0; s.active = s.id == id; return s }
        persistServers()
        refreshModels()
    }

    func testServer(_ id: Int) {
        updateServer(id) { $0.status = .testing }
        let base = servers.first(where: { $0.id == id })?.url ?? ""
        Task {
            let ok = (try? await NetworkManager.shared.testConnection(to: base)) ?? false
            self.updateServer(id) { $0.status = ok ? .online : .offline }
        }
    }

    private func updateServer(_ id: Int, _ mutate: (inout LLMServer) -> Void) {
        if let i = servers.firstIndex(where: { $0.id == id }) {
            var s = servers[i]; mutate(&s); servers[i] = s
        }
    }

    var canSaveServer: Bool { !addName.trimmingCharacters(in: .whitespaces).isEmpty && !addUrl.trimmingCharacters(in: .whitespaces).isEmpty }

    func toggleAddServer() {
        addOpen.toggle()
        addName = ""; addUrl = ""; addStatus = .idle
    }

    func testAddServer() {
        guard !addUrl.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        addStatus = .testing
        Task {
            let ok = (try? await NetworkManager.shared.testConnection(to: self.addUrl)) ?? false
            self.addStatus = ok ? .ok : .fail
        }
    }

    func saveServer() {
        guard canSaveServer else { return }
        let s = LLMServer(id: nextServerId, name: addName.trimmingCharacters(in: .whitespaces), url: addUrl.trimmingCharacters(in: .whitespaces), active: false, status: addStatus == .ok ? .online : .unknown)
        nextServerId += 1
        servers.append(s)
        persistServers()
        addOpen = false; addName = ""; addUrl = ""; addStatus = .idle
    }

    // MARK: - Navigation actions

    func openDrawer() { drawer = true }
    func closeDrawer() { drawer = false }

    func newChat() { activeChatId = nil; screen = .home }
    func newChatFromDrawer() { activeChatId = nil; screen = .home; drawer = false }

    func openSettingsFromDrawer() { screen = .settings; drawer = false }
    func closeSettings() { screen = activeChatId != nil ? .chat : .home }

    func openChats() { screen = .chats; drawer = false }
    func closeChats() { screen = activeChatId != nil ? .chat : .home }
    func openChat(_ id: Int) { activeChatId = id; screen = .chat }
    func openChatFromDrawer(_ id: Int) { activeChatId = id; screen = .chat; drawer = false }

    func openProjects() { screen = .projects; drawer = false }
    func closeProjects() { screen = activeChatId != nil ? .chat : .home }
    func openProject(_ id: Int) { activeProjectId = id; screen = .project }
    func closeProject() { screen = .projects }

    func openConnections() { screen = .connections }
    func closeConnections() { screen = .settings; addConnOpen = false }
    func openAddConn() { addConnOpen = true }
    func closeAddConn() { addConnOpen = false }

    func openNewProject() { newProjOpen = true; npName = ""; npDesc = ""; npRepo = nil; repoPickerOpen = false }
    func closeNewProject() { newProjOpen = false }

    func openSheet() { modelSheet = true }
    func closeSheet() { modelSheet = false }

    // MARK: - Connections

    func toggleConnection(_ id: String) {
        connections = connections.map { var c = $0; if c.id == id { c.connected.toggle() }; return c }
    }

    var connSummary: String {
        let on = connections.filter { $0.connected }
        return on.isEmpty ? "None connected" : on.map { $0.name }.joined(separator: ", ")
    }

    // MARK: - Projects

    func createProject() {
        let name = npName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let desc = npDesc.trimmingCharacters(in: .whitespaces)
        let p = ChatProject(id: nextProjectId, name: name, desc: desc.isEmpty ? "No description yet." : desc, files: 0, updated: "just now", chatIds: [], repo: npRepo)
        nextProjectId += 1
        projects.insert(p, at: 0)
        newProjOpen = false
        activeProjectId = p.id
        screen = .project
    }

    var activeProject: ChatProject? { projects.first(where: { $0.id == activeProjectId }) }

    // MARK: - Composer actions

    func toggleAttach() { attach = attach == nil ? "Q2-tickets.pdf" : nil }
    func clearAttach() { attach = nil }

    var sendBg: Color {
        !input.trimmingCharacters(in: .whitespaces).isEmpty ? ChatTheme.text(mode) : ChatTheme.line2(mode)
    }

    // MARK: - Chat send / stream

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !streaming else { return }

        let chatId: Int
        if let existing = activeChatId {
            chatId = existing
        } else {
            chatId = nextChatId
            nextChatId += 1
            let c = Chat(id: chatId, title: String(trimmed.prefix(42)), time: "Just now", messages: [])
            chats.insert(c, at: 0)
            activeChatId = chatId
        }

        let userMsg = ThreadMessage(role: .user, text: trimmed + (attach != nil ? "  📎" : ""))
        let asstMsg = ThreadMessage(role: .assistant, blocks: [], streaming: true)
        append(to: chatId, messages: [userMsg, asstMsg])

        input = ""
        attach = nil
        screen = .chat
        drawer = false

        startStream(chatId: chatId)
    }

    func usePrompt(_ label: String) { send(label) }

    private func append(to chatId: Int, messages: [ThreadMessage]) {
        guard let i = chats.firstIndex(where: { $0.id == chatId }) else { return }
        chats[i].messages.append(contentsOf: messages)
    }

    private func startStream(chatId: Int) {
        streaming = true
        tok = 0

        // Build request history from the UI message model.
        let history: [ThreadMessage] = chats.first(where: { $0.id == chatId })?.messages ?? []
        let requestMessages: [ChatMessage] = history.map { m in
            ChatMessage(role: m.role == .user ? "user" : "assistant", content: m.role == .user ? m.text : m.blocks.plainText)
        }

        let systemPrompt = PersonalizationStore().load().systemPrompt()
        let base = serverBase
        let model = activeModel.isEmpty ? (models.first?.name ?? "") : activeModel

        // Fall back to a canned demo stream when no server is configured.
        if base.isEmpty {
            demoStream(chatId: chatId)
            return
        }

        Task {
            do {
                try await NetworkManager.shared.sendChatMessageStreaming(
                    to: base,
                    model: model,
                    messages: requestMessages,
                    systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
                    onChunk: { chunk in
                        Task { @MainActor in
                            self.appendChunk(chunk, to: chatId)
                        }
                    }
                )
                self.finishStream(chatId: chatId)
            } catch {
                self.appendChunk("\n[error: \(error.localizedDescription)]", to: chatId)
                self.finishStream(chatId: chatId)
            }
        }
    }

    /// Append a raw chunk to the streaming assistant message, re-parsing
    /// into text/code blocks on the fly.
    private func appendChunk(_ chunk: String, to chatId: Int) {
        guard let ci = chats.firstIndex(where: { $0.id == chatId }) else { return }
        guard let mi = chats[ci].messages.indices.last, chats[ci].messages[mi].role == .assistant else { return }
        var msg = chats[ci].messages[mi]
        msg.rawStream += chunk
        msg.blocks = MessageBlock.parse(msg.rawStream)
        chats[ci].messages[mi] = msg
        tok += 1
    }

    private func finishStream(chatId: Int) {
        guard let ci = chats.firstIndex(where: { $0.id == chatId }) else { streaming = false; return }
        guard let mi = chats[ci].messages.indices.last, chats[ci].messages[mi].role == .assistant else { streaming = false; return }
        chats[ci].messages[mi].streaming = false
        streaming = false
    }

    func stop() {
        if let id = activeChatId { finishStream(chatId: id) }
    }

    func regen() {
        guard let id = activeChatId, let ci = chats.firstIndex(where: { $0.id == id }) else { return }
        if !chats[ci].messages.isEmpty {
            chats[ci].messages.removeLast() // drop last assistant reply
        }
        chats[ci].messages.append(ThreadMessage(role: .assistant, blocks: [], streaming: true))
        startStream(chatId: id)
    }

    // MARK: - Demo stream (no server configured)

    private func demoStream(chatId: Int) {
        let full = "Here's a launch command for serving Llama-3.3-70B AWQ on your Mac Studio node. vLLM shards the model across available GPUs and exposes an OpenAI-compatible endpoint this app connects to.\n\n```bash\nvllm serve casperhansen/llama-3.3-70b-instruct-awq \\\n  --quantization awq_marlin \\\n  --max-model-len 16384 \\\n  --gpu-memory-utilization 0.92 \\\n  --port 8000\n```\n\nOnce it is up, point Settings at http://<host>:8000/v1 and run a connection test. Want me to size --max-model-len for your context needs?"
        var i = full.startIndex
        let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { t in
            guard i < full.endIndex else { t.invalidate(); self.finishStream(chatId: chatId); return }
            let next = full.index(i, offsetBy: 4, limitedBy: full.endIndex) ?? full.endIndex
            let piece = String(full[i..<next])
            i = next
            self.appendChunk(piece, to: chatId)
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - Derived

    var activeChat: Chat? { chats.first(where: { $0.id == activeChatId }) }

    var activeServerStatusLine: String {
        guard let s = activeServer else { return "No server configured" }
        if s.status == .online { return "Connected · \(s.name)" }
        return "\(s.status.label) · \(s.name)"
    }

    var activeModelShort: String { activeModel.isEmpty ? "No model" : activeModel }

    var statLine: String { "\(38 + (tok % 9)) tok/s · \(tok) tokens" }

    var filteredChatGroups: [(label: String, items: [Chat])] {
        let q = chatQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = q.isEmpty ? chats : chats.filter { $0.title.lowercased().contains(q) }
        let isToday: (String) -> Bool = { $0.hasPrefix("Today") || $0 == "Just now" }
        var groups: [(String, [Chat])] = []
        let today = filtered.filter { isToday($0.time) }
        let earlier = filtered.filter { !isToday($0.time) }
        if !today.isEmpty { groups.append(("Today", today)) }
        if !earlier.isEmpty { groups.append(("Previous 30 days", earlier)) }
        return groups
    }
}

// MARK: - Block helpers

extension Array where Element == MessageBlock {
    /// Concatenated raw text across blocks (used for streaming accumulation).
    var rawText: String {
        map {
            switch $0 {
            case .text(let t): return t
            case .code(let lang, let t): return "```\(lang)\n\(t)\n```"
            }
        }.joined()
    }

    /// Display text (no fence markers) — used when rebuilding request history.
    var plainText: String {
        map {
            switch $0 {
            case .text(let t): return t
            case .code(_, let t): return t
            }
        }.joined()
    }
}

extension MessageBlock {
    /// Split raw streamed text into text/code blocks on ``` fences.
    static func parse(_ raw: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        var rest = raw
        while let start = rest.range(of: "```") {
            let before = String(rest[..<start.lowerBound])
            if !before.isEmpty { blocks.append(.text(before)) }
            let afterOpen = rest[start.upperBound...]
            guard let newline = afterOpen.firstIndex(of: "\n") else {
                blocks.append(.text(String(rest[start.lowerBound...])))
                return blocks
            }
            let lang = String(afterOpen[..<newline]).trimmingCharacters(in: .whitespaces)
            let afterLang = afterOpen[afterOpen.index(after: newline)...]
            guard let close = afterLang.range(of: "```") else {
                blocks.append(.code(lang: lang, text: String(afterLang)))
                return blocks
            }
            let code = String(afterLang[..<close.lowerBound])
            blocks.append(.code(lang: lang, text: code.trimmingCharacters(in: .newlines)))
            rest = String(afterLang[close.upperBound...])
        }
        if !rest.isEmpty { blocks.append(.text(rest)) }
        return blocks
    }
}
