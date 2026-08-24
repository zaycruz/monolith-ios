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
import Security
import SwiftUI

private final class ServerCredentialStore {
    static let shared = ServerCredentialStore()
    private let service = "openaccesslabs.byollm-assistantOS.gateway-token"

    func token(for serverID: Int) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: String(serverID),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ token: String?, for serverID: Int) {
        let key: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: String(serverID),
        ]
        SecItemDelete(key as CFDictionary)
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty,
              let data = token.data(using: .utf8) else { return }
        var item = key
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}

struct DefaultServerConfiguration: Equatable {
    let id: String
    let name: String
    let url: String

    static func fromBundle(_ bundle: Bundle = .main) -> DefaultServerConfiguration? {
        let id = (bundle.object(forInfoDictionaryKey: "MonolithDefaultServerID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = (bundle.object(forInfoDictionaryKey: "MonolithDefaultServerName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let url = (bundle.object(forInfoDictionaryKey: "MonolithDefaultServerURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let values = [id, name, url]

        guard values.allSatisfy({ !$0.isEmpty && !$0.contains("$(") }),
              (try? NetworkManager.shared.normalizeServerAddress(url)) != nil else {
            return nil
        }
        return DefaultServerConfiguration(id: id, name: name, url: url)
    }
}

@MainActor
final class AppStore: ObservableObject {
    private let defaults: UserDefaults
    private let defaultServerConfiguration: DefaultServerConfiguration?
    private let network: MonolithNetworkClient
    private let githubAuthorization: any GitHubAuthorizationPresenting
    private static let seededDefaultServerIDsKey = "mc.seededDefaultServerIDs"


    // MARK: - Screen routing

    enum Screen: Equatable {
        case home, chat, settings, connections, chats, projects, project
    }

    @Published var screen: Screen = .home
    @Published var drawer = false
    @Published var modelSheet = false
    @Published var reasoningOpen = false
    @Published var addConnOpen = false
    @Published var newProjOpen = false

    @Published var isDark: Bool {
        didSet { defaults.set(isDark, forKey: "mc.isDark") }
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
    @Published private(set) var cancellationSettling = false
    @Published var tok = 0

    // MARK: - Servers / models

    @Published var servers: [LLMServer] = []
    @Published var models: [ChatModel] = []
    @Published var activeModel = ""
    @Published private(set) var modelLoadState: ModelLoadState = .idle
    @Published var reasoningEffort: ReasoningEffort {
        didSet { defaults.set(reasoningEffort.rawValue, forKey: "mc.reasoningEffort") }
    }
    @Published var selectedRuntime: AgentRuntime {
        didSet { defaults.set(selectedRuntime.rawValue, forKey: "mc.selectedRuntime") }
    }
    @Published private(set) var harnesses: [HarnessDescriptor] = HarnessDescriptor.builtIns
    private var supportsHarnessRouting = false
    private var nextServerId = 1

    // MARK: - Connections

    @Published var connections: [AppConnection] = []
    @Published private(set) var connectionLoadState: ConnectionLoadState = .idle
    @Published private(set) var githubRepositories: [GitHubRepository] = []
    @Published private(set) var repositoryLoadState: ConnectionLoadState = .idle
    @Published private(set) var githubAuthorizationState: GitHubAuthorizationState = .idle

    // MARK: - Projects

    @Published var projects: [ChatProject] = []
    @Published var activeProjectId: Int?
    @Published var npName = ""
    @Published var npDesc = ""
    @Published var npRepo: String?
    private var nextProjectId = 1

    // MARK: - Add server form

    @Published var addOpen = false
    @Published var addName = ""
    @Published var addUrl = ""
    @Published var addToken = ""
    @Published var addStatus: AddStatus = .idle
    @Published private(set) var editingServerID: Int?
    private var lastTestedServerURL: String?
    private var modelRefreshGeneration = 0
    private var connectionRefreshGeneration = 0
    private var repositoryRefreshGeneration = 0
    private var connectionTask: Task<Void, Never>?
    private var repositoryTask: Task<Void, Never>?
    private var githubAuthorizationTask: Task<Void, Never>?
    private var githubOperationGeneration = 0
    private var serverProbeGenerations: [Int: Int] = [:]
    private var formProbeGeneration = 0
    private var streamTask: Task<Void, Never>?
    private var activeStream: ActiveStream?
    private var textFlushTask: Task<Void, Never>?
    private var pendingStreamText = ""
    private var pendingTextIdentity: ActiveStream?


    enum AddStatus: Equatable { case idle, testing, ok, fail }
    enum ModelLoadState: Equatable { case idle, loading, loaded, empty, failed(String) }
    enum ConnectionLoadState: Equatable { case idle, loading, loaded, failed(String) }
    enum GitHubAuthorizationState: Equatable {
        case idle, authorizing, disconnecting, installationRequired(URL), failed(String)
    }

    private enum GitHubFlowError: LocalizedError {
        case invalidAuthorizationURL, invalidInstallationURL, invalidCallback, stateMismatch, denied(String)

        var errorDescription: String? {
            switch self {
            case .invalidAuthorizationURL: return "The Monolith server returned an invalid GitHub authorization URL."
            case .invalidInstallationURL: return "The Monolith server returned an invalid GitHub App installation URL."
            case .invalidCallback: return "GitHub returned an invalid authorization callback."
            case .stateMismatch: return "GitHub authorization could not be verified."
            case .denied(let message): return message
            }
        }
    }

    private struct GitHubOperationIdentity: Equatable {
        let generation: Int
        let serverID: Int
        let serverURL: String
        let apiToken: String?
    }

    private struct ActiveStream: Equatable {
        let requestID: UUID
        let chatID: Int
        let messageID: UUID
    }

    init(
        defaults: UserDefaults = .standard,
        defaultServerConfiguration: DefaultServerConfiguration? = .fromBundle(),
        network: MonolithNetworkClient = NetworkManager.shared,
        githubAuthorization: (any GitHubAuthorizationPresenting)? = nil
    ) {
        self.defaults = defaults
        self.defaultServerConfiguration = defaultServerConfiguration
        self.network = network
        self.githubAuthorization = githubAuthorization ?? GitHubAuthorizationSession()
        self.isDark = defaults.bool(forKey: "mc.isDark")
        self.reasoningEffort = ReasoningEffort(
            rawValue: defaults.string(forKey: "mc.reasoningEffort") ?? ""
        ) ?? .medium
        self.selectedRuntime = AgentRuntime(
            rawValue: defaults.string(forKey: "mc.selectedRuntime") ?? AgentRuntime.pi.rawValue
        )
        loadServers()
    }

    // MARK: - Server persistence

    private func loadServers() {
        if let data = defaults.data(forKey: "mc.servers"),
           let saved = try? JSONDecoder().decode([SavedServer].self, from: data), !saved.isEmpty {
            servers = saved.map { server in
                nextServerId = max(nextServerId, server.id + 1)
                return LLMServer(
                    id: server.id,
                    name: server.name,
                    url: server.url,
                    active: server.active,
                    status: .unknown,
                    apiToken: server.authenticated == true ? ServerCredentialStore.shared.token(for: server.id) : nil
                )
            }
        } else {
            servers = []
            nextServerId = 1
        }

        var serversChanged = seedDefaultServerIfNeeded()
        if !servers.contains(where: { $0.active }), !servers.isEmpty {
            servers[0].active = true
            serversChanged = true
        }
        if serversChanged {
            persistServers()
        }
        refreshModels()
        refreshConnections()
    }

    private func seedDefaultServerIfNeeded() -> Bool {
        guard let configuration = defaultServerConfiguration,
              let canonicalURL = serverURLIdentity(configuration.url) else {
            return false
        }

        var seededIDs = Set(defaults.stringArray(forKey: Self.seededDefaultServerIDsKey) ?? [])
        guard !seededIDs.contains(configuration.id) else {
            return false
        }

        // A new build-configured server supersedes a previously configured
        // default once, while the first configured default preserves any
        // server that the user already selected.
        let shouldPromote = !seededIDs.isEmpty
        var changed = false
        if let existingIndex = servers.firstIndex(where: {
            serverURLIdentity($0.url) == canonicalURL
        }) {
            if shouldPromote && !servers[existingIndex].active {
                for index in servers.indices {
                    servers[index].active = index == existingIndex
                }
                changed = true
            }
        } else {
            let shouldActivate = shouldPromote || !servers.contains(where: { $0.active })
            if shouldActivate {
                for index in servers.indices {
                    servers[index].active = false
                }
            }
            servers.append(
                LLMServer(
                    id: nextServerId,
                    name: configuration.name,
                    url: configuration.url,
                    active: shouldActivate,
                    status: .unknown
                )
            )
            nextServerId += 1
            changed = true
        }

        seededIDs.insert(configuration.id)
        defaults.set(Array(seededIDs).sorted(), forKey: Self.seededDefaultServerIDsKey)
        return changed
    }

    private func persistServers() {
        let saved = servers.map {
            SavedServer(id: $0.id, name: $0.name, url: $0.url, active: $0.active, authenticated: $0.apiToken?.isEmpty == false)
        }
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: "mc.servers")
        }
    }

    private struct SavedServer: Codable {
        let id: Int
        var name: String
        var url: String
        var active: Bool
        var authenticated: Bool?
    }

    var activeServer: LLMServer? {
        servers.first(where: { $0.active }) ?? servers.first
    }

    var isChatReady: Bool {
        activeServer != nil && !activeModel.isEmpty && modelLoadState == .loaded && !cancellationSettling
    }

    private func serverURLIdentity(_ value: String) -> String? {
        try? network.normalizeServerAddress(value)
    }

    // MARK: - Models

    func refreshModels() {
        modelRefreshGeneration += 1
        let generation = modelRefreshGeneration
        guard let server = activeServer,
              let canonicalURL = serverURLIdentity(server.url) else {
            models = []
            activeModel = ""
            modelLoadState = .idle
            return
        }
        let serverID = server.id
        let probeGeneration = serverProbeGenerations[serverID]
        modelLoadState = .loading
        supportsHarnessRouting = false

        Task {
            do {
                async let modelRequest = network.getModels(from: canonicalURL, apiToken: server.apiToken)
                async let runtimeRequest = network.getRuntimes(from: canonicalURL, apiToken: server.apiToken)
                let list = try await modelRequest
                let remoteRuntimes = (try? await runtimeRequest) ?? []
                guard self.modelRefreshGeneration == generation,
                      self.activeServer?.id == serverID,
                      self.activeServer.flatMap({ self.serverURLIdentity($0.url) }) == canonicalURL else {
                    return
                }
                self.supportsHarnessRouting = !remoteRuntimes.isEmpty
                let normalizedModels = remoteRuntimes.isEmpty
                    ? list.map { RemoteModel(name: $0.name, runtime: nil) }
                    : list
                self.harnesses = self.harnessDescriptors(remoteRuntimes, models: normalizedModels)
                self.models = normalizedModels.map {
                    ChatModel(name: $0.name, meta: self.runtimeName(for: $0.runtime), runtime: $0.runtime)
                }
                let targetRuntime = self.currentRuntime
                let compatible = normalizedModels.filter { $0.runtime == nil || $0.runtime == targetRuntime }
                if let first = compatible.first ?? (normalizedModels.allSatisfy { $0.runtime == nil } ? normalizedModels.first : nil) {
                    let remembered = self.defaults.string(forKey: "mc.model.\(serverID)")
                    if let remembered, compatible.contains(where: { $0.name == remembered }) {
                        self.activeModel = remembered
                    } else if self.activeModel.isEmpty || !compatible.contains(where: { $0.name == self.activeModel }) {
                        self.activeModel = first.name
                    }
                    self.modelLoadState = .loaded
                } else {
                    self.activeModel = ""
                    self.modelLoadState = .empty
                }
                if self.serverProbeGenerations[serverID] == probeGeneration {
                    self.updateServer(serverID) { $0.status = .online }
                }
            } catch {
                guard self.modelRefreshGeneration == generation,
                      self.activeServer?.id == serverID,
                      self.activeServer.flatMap({ self.serverURLIdentity($0.url) }) == canonicalURL else {
                    return
                }
                self.models = []
                self.activeModel = ""
                self.modelLoadState = .failed(error.localizedDescription)
                if self.serverProbeGenerations[serverID] == probeGeneration {
                    self.updateServer(serverID) { $0.status = .offline }
                }
            }
        }
    }

    func pickModel(_ name: String) {
        guard let model = models.first(where: { $0.name == name }) else { return }
        if let runtime = model.runtime {
            if activeChat != nil, runtime != currentRuntime { return }
            if activeChat == nil { selectedRuntime = runtime }
        }
        activeModel = name
        if let serverID = activeServer?.id {
            defaults.set(name, forKey: "mc.model.\(serverID)")
        }
        modelSheet = false
    }

    var selectableModels: [ChatModel] {
        guard activeChat != nil else { return models }
        return models.filter { $0.runtime == nil || $0.runtime == currentRuntime }
    }

    func selectRuntime(_ runtime: AgentRuntime) {
        guard activeChat == nil, !streaming else { return }
        guard harnesses.first(where: { $0.runtime == runtime })?.available != false else { return }
        selectedRuntime = runtime
        if let compatible = models.first(where: { $0.runtime == runtime }) {
            pickModel(compatible.name)
            modelLoadState = .loaded
        } else if models.contains(where: { $0.runtime != nil }) {
            activeModel = ""
            modelLoadState = .empty
        }
    }

    private func harnessDescriptors(_ remote: [RemoteRuntime], models: [RemoteModel]) -> [HarnessDescriptor] {
        if !remote.isEmpty {
            return remote.map {
                HarnessDescriptor(
                    runtime: AgentRuntime(rawValue: $0.id),
                    name: $0.name,
                    available: $0.available,
                    model: $0.model,
                    unavailableReason: $0.unavailableReason
                )
            }
        }

        let inferred = Dictionary(grouping: models.compactMap { model in
            model.runtime.map { ($0, model.name) }
        }, by: { $0.0 }).values.compactMap { entries -> HarnessDescriptor? in
            guard let (runtime, model) = entries.first else { return nil }
            return HarnessDescriptor(runtime: runtime, name: runtime.title, available: true, model: model, unavailableReason: nil)
        }
        return inferred.isEmpty ? HarnessDescriptor.builtIns : inferred.sorted { $0.name < $1.name }
    }

    // MARK: - Server actions

    func selectServer(_ id: Int) {
        guard servers.contains(where: { $0.id == id }) else { return }
        if activeServer?.id == id {
            if models.isEmpty || modelLoadState != .loaded { refreshModels() }
            return
        }
        cancelGitHubAuthorization()
        servers = servers.map { server in
            var server = server
            server.active = server.id == id
            return server
        }
        models = []
        activeModel = ""
        persistServers()
        refreshModels()
        refreshConnections()
    }

    func deleteServer(_ id: Int) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = servers[index].active
        if wasActive { cancelGitHubAuthorization() }
        servers.remove(at: index)
        defaults.removeObject(forKey: "mc.model.\(id)")
        ServerCredentialStore.shared.set(nil, for: id)
        serverProbeGenerations[id, default: 0] += 1
        if wasActive { modelRefreshGeneration += 1 }

        if editingServerID == id { cancelServerForm() }
        if wasActive, !servers.isEmpty {
            let fallbackIndex = min(index, servers.count - 1)
            for serverIndex in servers.indices {
                servers[serverIndex].active = serverIndex == fallbackIndex
            }
        }
        persistServers()

        if wasActive || servers.isEmpty {
            models = []
            activeModel = ""
            modelLoadState = .idle
            if !servers.isEmpty { refreshModels() }
            refreshConnections()
        }
    }

    func testServer(_ id: Int) {
        guard let testedURL = servers.first(where: { $0.id == id })
            .flatMap({ serverURLIdentity($0.url) }) else {
            updateServer(id) { $0.status = .offline }
            return
        }
        serverProbeGenerations[id, default: 0] += 1
        let generation = serverProbeGenerations[id]
        updateServer(id) { $0.status = .testing }
        Task {
            let token = self.servers.first(where: { $0.id == id })?.apiToken
            let ok = (try? await network.testConnection(to: testedURL, apiToken: token)) ?? false
            guard self.serverProbeGenerations[id] == generation,
                  self.servers.first(where: { $0.id == id })
                .flatMap({ self.serverURLIdentity($0.url) }) == testedURL else {
                return
            }
            self.updateServer(id) { $0.status = ok ? .online : .offline }
        }
    }

    private func updateServer(_ id: Int, _ mutate: (inout LLMServer) -> Void) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            var server = servers[index]
            mutate(&server)
            servers[index] = server
        }
    }

    private var formURLIdentity: String? {
        serverURLIdentity(addUrl)
    }

    private var hasDuplicateServerURL: Bool {
        guard let canonicalURL = formURLIdentity else {
            return false
        }
        return servers.contains {
            $0.id != editingServerID && serverURLIdentity($0.url) == canonicalURL
        }
    }

    var serverFormTitle: String {
        editingServerID == nil ? "Add server" : "Edit server"
    }

    var serverFormSaveLabel: String {
        editingServerID == nil ? "Add server" : "Save changes"
    }

    var serverFormError: String? {
        if !addUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           formURLIdentity == nil {
            return "Enter a valid HTTP or HTTPS server address."
        }
        if hasDuplicateServerURL {
            return "This server is already in your list."
        }
        return nil
    }

    var canSaveServer: Bool {
        !addName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && formURLIdentity != nil
            && !hasDuplicateServerURL
    }

    func beginAddingServer() {
        formProbeGeneration += 1
        editingServerID = nil
        addName = ""
        addUrl = ""
        addToken = ""
        addStatus = .idle
        lastTestedServerURL = nil
        addOpen = true
    }

    func beginEditingServer(_ id: Int) {
        guard let server = servers.first(where: { $0.id == id }) else {
            return
        }
        formProbeGeneration += 1
        editingServerID = id
        addName = server.name
        addUrl = server.url
        addToken = server.apiToken ?? ""
        addStatus = .idle
        lastTestedServerURL = nil
        addOpen = true
    }

    func cancelServerForm() {
        formProbeGeneration += 1
        addOpen = false
        editingServerID = nil
        addName = ""
        addUrl = ""
        addToken = ""
        addStatus = .idle
        lastTestedServerURL = nil
    }

    func serverFormURLDidChange() {
        formProbeGeneration += 1
        if addStatus == .testing || (lastTestedServerURL != nil && formURLIdentity != lastTestedServerURL) {
            addStatus = .idle
            lastTestedServerURL = nil
        }
    }

    func serverFormTokenDidChange() {
        formProbeGeneration += 1
        addStatus = .idle
        lastTestedServerURL = nil
    }

    func testAddServer() {
        guard let testedURL = formURLIdentity else {
            addStatus = .fail
            return
        }
        formProbeGeneration += 1
        let generation = formProbeGeneration
        let token = addToken.trimmingCharacters(in: .whitespacesAndNewlines)
        addStatus = .testing
        Task {
            let ok = (try? await network.testConnection(to: testedURL, apiToken: token.isEmpty ? nil : token)) ?? false
            guard self.formProbeGeneration == generation,
                  self.formURLIdentity == testedURL,
                  self.addToken.trimmingCharacters(in: .whitespacesAndNewlines) == token else {
                return
            }
            self.lastTestedServerURL = testedURL
            self.addStatus = ok ? .ok : .fail
        }
    }

    private func testedFormStatus(for canonicalURL: String) -> ServerStatus? {
        guard lastTestedServerURL == canonicalURL else {
            return nil
        }
        switch addStatus {
        case .ok: return .online
        case .fail: return .offline
        case .idle, .testing: return nil
        }
    }

    func saveServer() {
        guard canSaveServer, let canonicalURL = formURLIdentity else {
            return
        }
        let name = addName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = addUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiToken = addToken.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingServerID,
           let index = servers.firstIndex(where: { $0.id == editingServerID }) {
            var server = servers[index]
            let endpointChanged = serverURLIdentity(server.url) != canonicalURL
            let credentialChanged = (server.apiToken ?? "") != apiToken
            if server.active && (endpointChanged || credentialChanged) {
                cancelGitHubAuthorization()
            }
            server.name = name
            server.url = url
            server.apiToken = apiToken.isEmpty ? nil : apiToken
            if endpointChanged {
                server.status = testedFormStatus(for: canonicalURL) ?? .unknown
            } else if let testedStatus = testedFormStatus(for: canonicalURL) {
                server.status = testedStatus
            }
            servers[index] = server
            ServerCredentialStore.shared.set(server.apiToken, for: server.id)
            persistServers()

            if server.active && (endpointChanged || credentialChanged) {
                models = []
                activeModel = ""
                refreshModels()
                refreshConnections()
            }
        } else {
            let shouldActivate = !servers.contains(where: { $0.active })
            let server = LLMServer(
                id: nextServerId,
                name: name,
                url: url,
                active: shouldActivate,
                status: testedFormStatus(for: canonicalURL) ?? .unknown,
                apiToken: apiToken.isEmpty ? nil : apiToken
            )
            nextServerId += 1
            servers.append(server)
            ServerCredentialStore.shared.set(server.apiToken, for: server.id)
            persistServers()
            if shouldActivate {
                refreshModels()
                refreshConnections()
            }
        }
        cancelServerForm()
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
    func openChat(_ id: Int) { activateChat(id); screen = .chat }
    func openChatFromDrawer(_ id: Int) { activateChat(id); screen = .chat; drawer = false }

    private func activateChat(_ id: Int) {
        guard chats.contains(where: { $0.id == id }) else { return }
        activeChatId = id
        let compatible = models.filter { $0.runtime == nil || $0.runtime == currentRuntime }
        if !compatible.contains(where: { $0.name == activeModel }) {
            activeModel = compatible.first?.name ?? ""
        }
    }

    func openProjects() { screen = .projects; drawer = false }
    func closeProjects() { screen = activeChatId != nil ? .chat : .home }
    func openProject(_ id: Int) { activeProjectId = id; screen = .project }
    func closeProject() { screen = .projects }

    func openConnections() { screen = .connections; refreshConnections() }
    func closeConnections() { screen = .settings; addConnOpen = false }
    func openAddConn() { addConnOpen = true }
    func closeAddConn() { addConnOpen = false }
    func dismissAddConnection() {
        cancelGitHubAuthorization()
        addConnOpen = false
    }

    func openNewProject() {
        newProjOpen = true
        npName = ""
        npDesc = ""
        npRepo = nil
    }
    func closeNewProject() { newProjOpen = false }

    func openSheet() {
        modelSheet = true
        if models.isEmpty, activeServer != nil { refreshModels() }
    }
    func closeSheet() { modelSheet = false }

    // MARK: - Connections

    var githubConnected: Bool {
        connections.contains(where: {
            $0.id == "github" && $0.connected && $0.installationRequired != true
        })
    }

    func refreshConnections() {
        connectionTask?.cancel()
        repositoryTask?.cancel()
        connectionRefreshGeneration += 1
        repositoryRefreshGeneration += 1
        let generation = connectionRefreshGeneration
        connections = []
        githubRepositories = []
        npRepo = nil
        repositoryLoadState = .idle
        guard let server = activeServer,
              let canonicalURL = serverURLIdentity(server.url) else {
            connectionLoadState = .idle
            if !githubOperationIsActive { githubAuthorizationState = .idle }
            return
        }
        connectionLoadState = .loading
        connectionTask = Task {
            do {
                let remote = try await network.getConnections(from: canonicalURL, apiToken: server.apiToken)
                guard self.connectionRefreshGeneration == generation,
                      self.activeServer?.id == server.id,
                      self.activeServer.flatMap({ self.serverURLIdentity($0.url) }) == canonicalURL else { return }
                let refreshedGitHubState = try self.githubState(from: remote)
                self.connections = remote
                self.connectionLoadState = .loaded
                if !self.githubOperationIsActive {
                    self.githubAuthorizationState = refreshedGitHubState
                }
                if !self.githubConnected {
                    self.githubRepositories = []
                    self.npRepo = nil
                    self.repositoryLoadState = .idle
                }
            } catch {
                guard self.connectionRefreshGeneration == generation,
                      self.activeServer?.id == server.id,
                      self.activeServer.flatMap({ self.serverURLIdentity($0.url) }) == canonicalURL else { return }
                self.connections = []
                self.githubRepositories = []
                self.npRepo = nil
                self.connectionLoadState = .failed(error.localizedDescription)
                self.repositoryLoadState = .idle
                if !self.githubOperationIsActive {
                    self.githubAuthorizationState = .failed(error.localizedDescription)
                }
            }
        }
    }

    func refreshGitHubRepositories() {
        guard repositoryLoadState != .loading else { return }
        repositoryTask?.cancel()
        repositoryRefreshGeneration += 1
        let generation = repositoryRefreshGeneration
        guard githubConnected,
              let server = activeServer,
              let canonicalURL = serverURLIdentity(server.url) else {
            githubRepositories = []
            npRepo = nil
            repositoryLoadState = .idle
            return
        }
        githubRepositories = []
        repositoryLoadState = .loading
        repositoryTask = Task {
            do {
                let remote = try await network.getGitHubRepositories(from: canonicalURL, apiToken: server.apiToken)
                guard self.repositoryRefreshGeneration == generation,
                      self.activeServer?.id == server.id,
                      self.activeServer.flatMap({ self.serverURLIdentity($0.url) }) == canonicalURL else { return }
                self.githubRepositories = remote
                if let selected = self.npRepo,
                   !remote.contains(where: { $0.fullName == selected }) {
                    self.npRepo = nil
                }
                self.repositoryLoadState = .loaded
            } catch {
                guard self.repositoryRefreshGeneration == generation,
                      self.activeServer?.id == server.id,
                      self.activeServer.flatMap({ self.serverURLIdentity($0.url) }) == canonicalURL else { return }
                self.githubRepositories = []
                self.npRepo = nil
                self.repositoryLoadState = .failed(error.localizedDescription)
            }
        }
    }

    func selectRepository(_ fullName: String) {
        guard repositoryLoadState == .loaded else { return }
        guard githubRepositories.contains(where: { $0.fullName == fullName }) else { return }
        npRepo = fullName
    }

    func connectGitHub() {
        cancelGitHubAuthorization()
        guard let server = activeServer,
              let canonicalURL = serverURLIdentity(server.url) else {
            githubAuthorizationState = .failed("Add and select a Monolith server first.")
            return
        }
        let operation = beginGitHubOperation(for: server, canonicalURL: canonicalURL)
        githubAuthorizationState = .authorizing
        githubAuthorizationTask = Task {
            defer {
                if self.isCurrentGitHubOperation(operation) {
                    self.githubAuthorizationTask = nil
                }
            }
            do {
                let start = try await network.startGitHubOAuth(from: canonicalURL, apiToken: server.apiToken)
                try Task.checkCancellation()
                guard isCurrentGitHubOperation(operation) else { return }
                try validateGitHubAuthorizationStart(start)
                let callback = try await githubAuthorization.authorize(
                    at: start.authorizationURL,
                    callbackScheme: "monolith"
                )
                try Task.checkCancellation()
                guard isCurrentGitHubOperation(operation) else { return }
                let callbackValues = try githubCallbackValues(callback)
                guard callbackValues.state == start.state else { throw GitHubFlowError.stateMismatch }
                let result = try await network.completeGitHubOAuth(
                    from: canonicalURL,
                    apiToken: server.apiToken,
                    flowID: start.flowID,
                    state: callbackValues.state,
                    code: callbackValues.code
                )
                try Task.checkCancellation()
                guard isCurrentGitHubOperation(operation) else { return }
                try applyGitHubOAuthResult(result)
            } catch is CancellationError {
                if isCurrentGitHubOperation(operation) { githubAuthorizationState = .idle }
            } catch let error as URLError where error.code == .cancelled {
                if isCurrentGitHubOperation(operation) { githubAuthorizationState = .idle }
            } catch {
                if isCurrentGitHubOperation(operation) {
                    githubAuthorizationState = .failed(error.localizedDescription)
                }
            }
        }
    }

    func disconnectGitHub() {
        guard let server = activeServer,
              let canonicalURL = serverURLIdentity(server.url) else { return }
        cancelGitHubAuthorization()
        let operation = beginGitHubOperation(for: server, canonicalURL: canonicalURL)
        githubAuthorizationState = .disconnecting
        githubAuthorizationTask = Task {
            defer {
                if self.isCurrentGitHubOperation(operation) {
                    self.githubAuthorizationTask = nil
                }
            }
            do {
                try await network.disconnectGitHub(from: canonicalURL, apiToken: server.apiToken)
                try Task.checkCancellation()
                guard isCurrentGitHubOperation(operation) else { return }
                githubAuthorizationState = .idle
                closeAddConn()
                refreshConnections()
            } catch is CancellationError {
                if isCurrentGitHubOperation(operation) { githubAuthorizationState = .idle }
            } catch {
                if isCurrentGitHubOperation(operation) {
                    githubAuthorizationState = .failed(error.localizedDescription)
                }
            }
        }
    }

    func cancelGitHubAuthorization() {
        githubOperationGeneration += 1
        let task = githubAuthorizationTask
        githubAuthorizationTask = nil
        task?.cancel()
        githubAuthorization.cancel()
        if githubOperationIsActive { githubAuthorizationState = .idle }
    }

    private var githubOperationIsActive: Bool {
        switch githubAuthorizationState {
        case .authorizing, .disconnecting: return true
        case .idle, .installationRequired, .failed: return false
        }
    }

    private func beginGitHubOperation(for server: LLMServer, canonicalURL: String) -> GitHubOperationIdentity {
        githubOperationGeneration += 1
        return GitHubOperationIdentity(
            generation: githubOperationGeneration,
            serverID: server.id,
            serverURL: canonicalURL,
            apiToken: server.apiToken
        )
    }

    private func isCurrentGitHubOperation(_ operation: GitHubOperationIdentity) -> Bool {
        githubOperationGeneration == operation.generation
            && activeServer?.id == operation.serverID
            && activeServer.flatMap({ serverURLIdentity($0.url) }) == operation.serverURL
            && activeServer?.apiToken == operation.apiToken
    }

    private func githubState(from connections: [AppConnection]) throws -> GitHubAuthorizationState {
        guard let github = connections.first(where: { $0.id == "github" }), github.connected else {
            return .idle
        }
        guard github.installationRequired == true else { return .idle }
        guard let value = github.installationURL, let url = URL(string: value) else {
            throw GitHubFlowError.invalidInstallationURL
        }
        return .installationRequired(try validatedGitHubInstallationURL(url))
    }

    private func applyGitHubOAuthResult(_ result: GitHubOAuthResult) throws {
        let installationURL = result.installationRequired
            ? try validatedGitHubInstallationURL(result.installationURL)
            : nil
        let existing = connections.first(where: { $0.id == "github" })
        let returnedAccount = result.account?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let account = returnedAccount.isEmpty ? (existing?.account ?? "") : returnedAccount
        let connection = AppConnection(
            id: "github",
            name: existing?.name ?? "GitHub",
            desc: result.installationRequired
                ? "Install the Monolith GitHub App to choose repositories."
                : "Repository access was authorized from the Monolith app.",
            account: account,
            connected: true,
            installationRequired: result.installationRequired,
            installationURL: installationURL?.absoluteString
        )

        connectionTask?.cancel()
        repositoryTask?.cancel()
        connectionTask = nil
        repositoryTask = nil
        connectionRefreshGeneration += 1
        repositoryRefreshGeneration += 1
        githubRepositories = []
        npRepo = nil
        repositoryLoadState = .idle
        connectionLoadState = .loaded
        if let index = connections.firstIndex(where: { $0.id == "github" }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }

        if let installationURL {
            githubAuthorizationState = .installationRequired(installationURL)
        } else {
            githubAuthorizationState = .idle
            closeAddConn()
        }
    }

    private func validatedGitHubInstallationURL(_ url: URL?) throws -> URL {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "github.com",
              components.user == nil,
              components.password == nil,
              components.port == nil || components.port == 443,
              components.query == nil,
              components.fragment == nil,
              components.percentEncodedPath.range(
                of: #"^/apps/[A-Za-z0-9-]+/installations/new$"#,
                options: .regularExpression
              ) != nil else {
            throw GitHubFlowError.invalidInstallationURL
        }
        return url
    }

    private func validateGitHubAuthorizationStart(_ start: GitHubOAuthStart) throws {
        guard start.authorizationURL.scheme == "https",
              start.authorizationURL.host == "github.com",
              start.authorizationURL.path == "/login/oauth/authorize",
              start.redirectURI.scheme == "monolith",
              start.redirectURI.host == "oauth",
              start.redirectURI.path == "/github" else {
            throw GitHubFlowError.invalidAuthorizationURL
        }
    }

    private func githubCallbackValues(_ callback: URL) throws -> (code: String, state: String) {
        guard callback.scheme == "monolith",
              callback.host == "oauth",
              callback.path == "/github",
              let components = URLComponents(url: callback, resolvingAgainstBaseURL: false) else {
            throw GitHubFlowError.invalidCallback
        }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard values[item.name] == nil else { throw GitHubFlowError.invalidCallback }
            values[item.name] = item.value ?? ""
        }
        if let error = values["error"] {
            throw GitHubFlowError.denied(values["error_description"] ?? error)
        }
        guard let code = values["code"], !code.isEmpty,
              let state = values["state"], !state.isEmpty else {
            throw GitHubFlowError.invalidCallback
        }
        return (code, state)
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
        let verifiedRepository: String?
        if let selected = npRepo,
           githubConnected,
           repositoryLoadState == .loaded,
           githubRepositories.contains(where: { $0.fullName == selected }) {
            verifiedRepository = selected
        } else {
            verifiedRepository = nil
        }
        let p = ChatProject(id: nextProjectId, name: name, desc: desc.isEmpty ? "No description yet." : desc, files: 0, updated: "just now", chatIds: [], repo: verifiedRepository)
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
        isChatReady
            && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !streaming
            ? ChatTheme.text(mode)
            : ChatTheme.line2(mode)
    }

    // MARK: - Chat send / stream

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !streaming, isChatReady else { return }

        let chatId: Int
        if let existing = activeChatId {
            chatId = existing
        } else {
            chatId = nextChatId
            nextChatId += 1
            let c = Chat(
                id: chatId,
                runtime: selectedRuntime,
                title: String(trimmed.prefix(42)),
                time: "Just now",
                messages: []
            )
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
        streamTask?.cancel()
        textFlushTask?.cancel()
        textFlushTask = nil
        pendingStreamText = ""
        pendingTextIdentity = nil
        streaming = true
        tok = 0

        // A stable per-chat ID lets the gateway preserve one runtime session.
        let chat = chats.first(where: { $0.id == chatId })
        let history: [ThreadMessage] = chat?.messages ?? []
        let agentSessionId = chat?.agentSessionId.uuidString
        let requestMessages: [ChatMessage] = history.map { m in
            ChatMessage(role: m.role == .user ? "user" : "assistant", content: m.role == .user ? m.text : m.blocks.plainText)
        }

        let systemPrompt = PersonalizationStore().load().systemPrompt()
        let base = activeServer.flatMap { serverURLIdentity($0.url) } ?? ""
        let model = activeModel.isEmpty ? (models.first?.name ?? "") : activeModel

        let runtime = chat?.runtime ?? selectedRuntime
        let modelRuntime = models.first(where: { $0.name == model })?.runtime
        guard !base.isEmpty, !model.isEmpty,
              modelRuntime == nil || modelRuntime == runtime,
              let messageID = history.last(where: { $0.role == .assistant })?.id else {
            streaming = false
            return
        }

        let identity = ActiveStream(requestID: UUID(), chatID: chatId, messageID: messageID)
        activeStream = identity
        let effort = reasoningEffort
        let apiToken = activeServer?.apiToken
        let routesHarnesses = supportsHarnessRouting

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.network.sendChatMessageStreaming(
                    to: base,
                    model: model,
                    messages: requestMessages,
                    systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
                    runtime: routesHarnesses ? runtime.rawValue : nil,
                    reasoningEffort: routesHarnesses ? effort.rawValue : nil,
                    conversationId: routesHarnesses ? agentSessionId : nil,
                    apiToken: apiToken,
                    onEvent: { event in
                        await self.receive(event, for: identity)
                    }
                )
                self.finishStream(identity)
            } catch {
                guard !Task.isCancelled, self.activeStream == identity else { return }
                self.appendText("\n[error: \(error.localizedDescription)]", for: identity)
                self.finishStream(identity)
            }
        }
    }

    private func receive(_ event: ChatStreamEvent, for identity: ActiveStream) {
        guard activeStream == identity else { return }
        switch event {
        case .textDelta(let text):
            queueText(text, for: identity)
        case .reasoningDelta:
            tok += 1
        case .toolStarted(let id, let name, let input):
            flushPendingText(for: identity)
            mutateMessage(for: identity) { message in
                message.blocks.append(.tool(ToolCallBlock(id: id, name: name, input: input, output: "", status: .running)))
                message.rawStream = ""
                message.textSegmentStart = message.blocks.count
            }
        case .toolUpdated(let id, let output):
            flushPendingText(for: identity)
            upsertTool(id: id, name: "Tool", for: identity) {
                $0.output = output
            }
        case .toolFinished(let id, let output, let isError):
            flushPendingText(for: identity)
            upsertTool(id: id, name: "Tool", for: identity) {
                $0.output = output
                $0.status = isError ? .failed : .succeeded
            }
        case .failure(let message):
            flushPendingText(for: identity)
            appendText("\n[error: \(message)]", for: identity)
        }
    }

    private func queueText(_ chunk: String, for identity: ActiveStream) {
        guard activeStream == identity else { return }
        if let pendingTextIdentity, pendingTextIdentity != identity {
            flushPendingText(for: pendingTextIdentity)
        }
        pendingTextIdentity = identity
        pendingStreamText += chunk
        guard textFlushTask == nil else { return }
        textFlushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            self?.flushPendingText(for: identity)
        }
    }

    private func flushPendingText(for identity: ActiveStream) {
        textFlushTask?.cancel()
        textFlushTask = nil
        guard pendingTextIdentity == identity, !pendingStreamText.isEmpty else {
            return
        }
        let text = pendingStreamText
        pendingStreamText = ""
        pendingTextIdentity = nil
        appendText(text, for: identity)
    }

    private func appendText(_ chunk: String, for identity: ActiveStream) {
        mutateMessage(for: identity) { msg in
            msg.rawStream += chunk
            let prefix = Array(msg.blocks.prefix(msg.textSegmentStart))
            let segment = msg.rawStream.contains("```") ? MessageBlock.parse(msg.rawStream) : [.text(msg.rawStream)]
            msg.blocks = prefix + segment
        }
        tok += 1
    }

    private func mutateMessage(for identity: ActiveStream, _ mutate: (inout ThreadMessage) -> Void) {
        guard activeStream == identity,
              let ci = chats.firstIndex(where: { $0.id == identity.chatID }),
              let mi = chats[ci].messages.firstIndex(where: { $0.id == identity.messageID }) else { return }
        var msg = chats[ci].messages[mi]
        mutate(&msg)
        chats[ci].messages[mi] = msg
    }

    private func upsertTool(
        id: String,
        name: String,
        for identity: ActiveStream,
        _ mutate: (inout ToolCallBlock) -> Void
    ) {
        mutateMessage(for: identity) { message in
            if let index = message.blocks.firstIndex(where: {
                if case .tool(let tool) = $0 { return tool.id == id }
                return false
            }), case .tool(var tool) = message.blocks[index] {
                mutate(&tool)
                message.blocks[index] = .tool(tool)
                return
            }
            var tool = ToolCallBlock(id: id, name: name, input: "", output: "", status: .running)
            mutate(&tool)
            message.blocks.append(.tool(tool))
            message.rawStream = ""
            message.textSegmentStart = message.blocks.count
        }
    }

    private func finishStream(_ identity: ActiveStream) {
        guard activeStream == identity else { return }
        flushPendingText(for: identity)
        mutateMessage(for: identity) { $0.streaming = false }
        activeStream = nil
        streamTask = nil
        streaming = false
    }

    func stop() {
        guard let identity = activeStream else { return }
        flushPendingText(for: identity)
        activeStream = nil
        textFlushTask?.cancel()
        textFlushTask = nil
        pendingStreamText = ""
        pendingTextIdentity = nil
        streamTask?.cancel()
        streamTask = nil
        if let ci = chats.firstIndex(where: { $0.id == identity.chatID }),
           let mi = chats[ci].messages.firstIndex(where: { $0.id == identity.messageID }) {
            chats[ci].messages[mi].streaming = false
            chats[ci].messages[mi].blocks = chats[ci].messages[mi].blocks.map { block in
                guard case .tool(var tool) = block, tool.status == .running else { return block }
                tool.status = .cancelled
                return .tool(tool)
            }
        }
        streaming = false
        cancellationSettling = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 850_000_000)
            self?.cancellationSettling = false
        }
    }

    func regen() {
        guard !cancellationSettling else { return }
        guard let id = activeChatId, let ci = chats.firstIndex(where: { $0.id == id }) else { return }
        if !chats[ci].messages.isEmpty {
            chats[ci].messages.removeLast() // drop last assistant reply
        }
        chats[ci].messages.append(ThreadMessage(role: .assistant, blocks: [], streaming: true))
        startStream(chatId: id)
    }


    var activeChat: Chat? { chats.first(where: { $0.id == activeChatId }) }

    var activeServerStatusLine: String {
        guard let s = activeServer else { return "No server configured" }
        if s.status == .online { return "Connected · \(s.name)" }
        return "\(s.status.label) · \(s.name)"
    }

    var activeModelShort: String { activeModel.isEmpty ? "No model" : activeModel }

    var currentRuntime: AgentRuntime { activeChat?.runtime ?? selectedRuntime }

    private func runtimeName(for runtime: AgentRuntime?) -> String {
        guard let runtime else { return "Loaded on server" }
        return harnesses.first(where: { $0.runtime == runtime })?.name ?? runtime.title
    }

    var currentRuntimeName: String {
        runtimeName(for: currentRuntime)
    }

    func dismissReasoning() {
        reasoningOpen = false
    }

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
            case .tool(let tool): return "[Tool: \(tool.name)]"
            }
        }.joined()
    }

    /// Display text (no fence markers) — used when rebuilding request history.
    var plainText: String {
        map {
            switch $0 {
            case .text(let t): return t
            case .code(_, let t): return t
            case .tool(let tool): return "Tool \(tool.name): \(tool.status)"
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
