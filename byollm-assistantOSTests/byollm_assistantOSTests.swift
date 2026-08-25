//
//  byollm_assistantOSTests.swift
//  byollm-assistantOSTests
//
//  Created by master on 11/16/25.
//

import Testing
import Foundation
@testable import byollm_assistantOS

struct byollm_assistantOSTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func personalizationSystemPrompt_includesUserInfoAndPreferences() async throws {
        let settings = PersonalizationSettings(
            fullName: "John Doe",
            nickname: "JD",
            personalPreferences: "Push me to be better. Always reference other chats."
        )
        
        let prompt = settings.systemPrompt()
        
        #expect(prompt.contains("About the user:"))
        #expect(prompt.contains("Name: John Doe"))
        #expect(prompt.contains("Nickname: JD"))
        #expect(prompt.contains("User preferences:"))
        #expect(prompt.contains("Push me to be better"))
    }
    
    @Test func personalizationStore_roundTripPersists() async throws {
        let suiteName = "byollm-assistantOS.tests.personalization"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        
        let store = PersonalizationStore(defaults: defaults)
        let original = PersonalizationSettings(
            fullName: "Test User",
            nickname: "Tester",
            personalPreferences: "Always be concise."
        )
        
        store.save(original)
        let loaded = store.load()
        
        #expect(loaded == original)
        #expect(defaults.string(forKey: "systemPrompt") == original.systemPrompt())
    }

    @Test func networkManager_normalizesOpenAIBaseURL() throws {
        #expect(try NetworkManager.shared.normalizeServerAddress("example.local:30000/v1") == "http://example.local:30000")
        #expect(try NetworkManager.shared.normalizeServerAddress("https://example.com/v1/") == "https://example.com")
        #expect(try NetworkManager.shared.normalizeServerAddress("http://example.com:8000") == "http://example.com:8000")
    }

    @Test func networkManager_requiresHTTPSWhenSendingGatewayTokenRemotely() throws {
        #expect(throws: NetworkManager.NetworkError.self) {
            try NetworkManager.shared.validatedServerAddress("http://10.0.0.5:31000", apiToken: "secret")
        }
        #expect(
            try NetworkManager.shared.validatedServerAddress("https://gateway.example.com/v1", apiToken: "secret")
                == "https://gateway.example.com"
        )
        #expect(
            try NetworkManager.shared.validatedServerAddress("http://127.0.0.1:31000", apiToken: "secret")
                == "http://127.0.0.1:31000"
        )
        #expect(
            try NetworkManager.shared.validatedServerAddress("http://127.255.0.1:31000", apiToken: "secret")
                == "http://127.255.0.1:31000"
        )
        #expect(
            try NetworkManager.shared.validatedServerAddress("http://[::1]:31000", apiToken: "secret")
                == "http://[::1]:31000"
        )
        #expect(throws: NetworkManager.NetworkError.self) {
            try NetworkManager.shared.validatedServerAddress("http://127.attacker.example:31000", apiToken: "secret")
        }
        #expect(throws: NetworkManager.NetworkError.self) {
            try NetworkManager.shared.validatedServerAddress(
                "http://gateway.example.com:31000",
                apiToken: nil,
                requiresSecureTransport: true
            )
        }
        #expect(
            try NetworkManager.shared.normalizeServerAddress("127.attacker.example:31000")
                == "https://127.attacker.example:31000"
        )
        #expect(try NetworkManager.shared.normalizeServerAddress("gateway.example.com:31000") == "https://gateway.example.com:31000")
    }

    @Test func chatRequest_encodesRuntimeSeparatelyFromProvider() throws {
        let request = ChatRequest(
            model: "codex-agent",
            messages: [ChatMessage(role: "user", content: "hello")],
            runtime: "codex",
            temperature: 0.7,
            stream: true,
            safetyLevel: nil
        )
        let object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(object["runtime"] as? String == "codex")
        #expect(object["provider"] == nil)
    }

    @Test func streamEvent_decodesObjectValuedToolPayloadAndRuntimeError() throws {
        let toolData = try #require(#"{"type":"tool_started","id":"call-1","name":"read","input":{"path":"README.md"}}"#.data(using: .utf8))
        let tool = try JSONDecoder().decode(MonolithStreamEvent.self, from: toolData)
        #expect(tool.event == .toolStarted(id: "call-1", name: "read", input: #"{"path":"README.md"}"#))

        let errorData = try #require(#"{"type":"error","message":"runtime stopped"}"#.data(using: .utf8))
        let error = try JSONDecoder().decode(MonolithStreamEvent.self, from: errorData)
        #expect(error.event == .failure("runtime stopped"))

        let updateData = try #require(
            #"{"type":"tool_updated","id":"call-2","name":"search","input":"swift","output":"result"}"#
                .data(using: .utf8)
        )
        let update = try JSONDecoder().decode(MonolithStreamEvent.self, from: updateData)
        #expect(update.event == .toolUpdated(id: "call-2", name: "search", input: "swift", output: "result"))

        let finishData = try #require(
            #"{"type":"tool_finished","id":"call-2","is_error":false}"#.data(using: .utf8)
        )
        let finish = try JSONDecoder().decode(MonolithStreamEvent.self, from: finishData)
        #expect(finish.event == .toolFinished(
            id: "call-2",
            name: nil,
            input: nil,
            output: nil,
            isError: false
        ))

        let cancelledData = try #require(#"{"type":"cancelled"}"#.data(using: .utf8))
        let cancelled = try JSONDecoder().decode(MonolithStreamEvent.self, from: cancelledData)
        #expect(cancelled.event == .cancelled)
    }

    @Test func serverSentEventDecoder_requiresValidDoneTerminator() throws {
        let payload = #"{"id":"chat-1","object":"chat.completion.chunk","model":"pi-agent","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}"#
        var decoder = ServerSentEventDecoder()

        let decodedResponse = try decoder.decode("data: \(payload)")
        let response = try #require(decodedResponse)
        #expect(response.choices.first?.delta.content == "Hello")
        #expect(throws: NetworkManager.NetworkError.self) {
            try decoder.validateCompletion()
        }
        let doneResponse = try decoder.decode("data: [DONE]")
        #expect(doneResponse == nil)
        try decoder.validateCompletion()

        var malformed = ServerSentEventDecoder()
        #expect(throws: NetworkManager.NetworkError.self) {
            _ = try malformed.decode("data: {not-json}")
        }
    }

    @Test func messageBlockParser_preservesFencedCodeAndStreamingBoundaries() {
        #expect(MessageBlock.parse("Plain response") == [.text("Plain response")])
        #expect(MessageBlock.parse("```swift") == [.code(lang: "swift", text: "")])
        #expect(
            MessageBlock.parse("Intro\r\n```swift\r\nlet value = 1\r\n```\r\nDone")
                == [
                    .text("Intro\n"),
                    .code(lang: "swift", text: "let value = 1"),
                    .text("\nDone"),
                ]
        )
        #expect(
            MessageBlock.parse("A\n```\none\n```\nB\n```json\n{}\n```\nC").count == 5
        )
    }

    @Test func githubOAuthResult_decodesAccountFromGatewayCompletion() throws {
        let data = try #require(
            #"{"connected":true,"account":"octocat","installation_required":false,"installation_url":null}"#
                .data(using: .utf8)
        )

        let result = try JSONDecoder().decode(ConnectionAuthorizationResult.self, from: data)

        #expect(result.account == "octocat")
        #expect(!result.requiresSetup)
        #expect(result.resolvedSetupURL == nil)
    }

    @Test func connectionModels_decodeGenericPluginFields() throws {
        let connectionData = try #require(
            #"{"id":"linear","name":"Linear","description":"Issue access","account":"team","connected":true,"available":true,"capabilities":["authorization","repositories"],"authorization":"oauth","resource_kind":"repository","setup_required":true,"setup_url":"https://linear.app/setup"}"#
                .data(using: .utf8)
        )
        let connection = try JSONDecoder().decode(AppConnection.self, from: connectionData)

        #expect(connection.id == "linear")
        #expect(connection.isAvailable)
        #expect(connection.supports("repositories"))
        #expect(connection.requiresSetup)
        #expect(connection.resolvedSetupURL == "https://linear.app/setup")

        let resultData = try #require(
            #"{"connection_id":"linear","connected":true,"account":"team","setup_required":true,"setup_url":"https://linear.app/setup"}"#
                .data(using: .utf8)
        )
        let result = try JSONDecoder().decode(ConnectionAuthorizationResult.self, from: resultData)

        #expect(result.connectionID == "linear")
        #expect(result.requiresSetup)
        #expect(result.resolvedSetupURL?.absoluteString == "https://linear.app/setup")
    }

    @Test func connectionRepository_decodesAuthoritativeAndLegacyIDs() throws {
        let genericData = try #require(
            #"{"id":"repo_42","connection_id":"gitlab","full_name":"team/app","private":true,"default_branch":"main"}"#
                .data(using: .utf8)
        )
        let legacyData = try #require(
            #"{"id":42,"full_name":"team/legacy","private":false,"default_branch":"trunk"}"#
                .data(using: .utf8)
        )

        let generic = try JSONDecoder().decode(ConnectionRepository.self, from: genericData)
        let legacy = try JSONDecoder().decode(ConnectionRepository.self, from: legacyData)

        #expect(generic.id == "repo_42")
        #expect(generic.connectionID == "gitlab")
        #expect(legacy.id == "42")
        // The network route, not an untrusted payload, supplies legacy GitHub identity.
        #expect(legacy.connectionID.isEmpty)
    }

    @Test func agentRuntime_supportsServerDefinedHarnesses() {
        let runtime = AgentRuntime(rawValue: "codex-cli")

        #expect(runtime.rawValue == "codex-cli")
        #expect(runtime.title == "Codex Cli")
        #expect(AgentRuntime.ohMyPi.title == "Oh My Pi")
    }

    @Test func speechTranscriptComposer_preservesTypedDraft() {
        #expect(SpeechTranscriptComposer.compose(draft: "Explain this", transcript: "in more detail") == "Explain this in more detail")
        #expect(SpeechTranscriptComposer.compose(draft: "", transcript: "New prompt") == "New prompt")
        #expect(SpeechTranscriptComposer.compose(draft: "Already spaced ", transcript: "correctly") == "Already spaced correctly")
    }

    @MainActor
    @Test func appStore_seedsConfiguredServerOnceWithoutDuplicatingURL() throws {
        let suiteName = "byollm-assistantOS.tests.default-server"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = DefaultServerConfiguration(
            id: "primary-local-server",
            name: "Example server",
            url: "http://127.0.0.1:9/v1"
        )
        let firstLaunch = AppStore(
            defaults: defaults,
            defaultServerConfiguration: configuration
        )

        #expect(firstLaunch.servers.count == 1)
        #expect(firstLaunch.servers[0].name == "Example server")
        #expect(firstLaunch.servers[0].active)

        let secondLaunch = AppStore(
            defaults: defaults,
            defaultServerConfiguration: configuration
        )
        #expect(secondLaunch.servers.count == 1)
        #expect(
            defaults.stringArray(forKey: "mc.seededDefaultServerIDs")
                == ["primary-local-server"]
        )
    }

    @MainActor
    @Test func appStore_defaultServerSuppressesCanonicalURLDuplicate() throws {
        let suiteName = "byollm-assistantOS.tests.default-server-duplicate"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let existingStore = AppStore(
            defaults: defaults,
            defaultServerConfiguration: nil
        )
        existingStore.addName = "Existing server"
        existingStore.addUrl = "http://127.0.0.1:9/v1/"
        existingStore.saveServer()

        let seededStore = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "primary-local-server",
                name: "Default server",
                url: "127.0.0.1:9/v1"
            )
        )

        #expect(seededStore.servers.count == 1)
        #expect(seededStore.servers[0].name == "Existing server")
    }

    @MainActor
    @Test func appStore_promotesReplacementConfiguredServerOnce() throws {
        let suiteName = "byollm-assistantOS.tests.default-server-replacement"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "configured-server-a",
                name: "Configured server A",
                url: "http://127.0.0.1:9/v1"
            )
        )
        let replacement = DefaultServerConfiguration(
            id: "configured-server-b",
            name: "Configured server B",
            url: "http://127.0.0.1:10/v1"
        )
        let upgradedStore = AppStore(
            defaults: defaults,
            defaultServerConfiguration: replacement
        )

        #expect(upgradedStore.servers.count == 2)
        #expect(upgradedStore.servers.first(where: { $0.url.contains(":9/") })?.active == false)
        #expect(upgradedStore.servers.first(where: { $0.url.contains(":10/") })?.active == true)

        let relaunchedStore = AppStore(
            defaults: defaults,
            defaultServerConfiguration: replacement
        )
        #expect(relaunchedStore.servers.count == 2)
        #expect(relaunchedStore.servers.filter(\.active).count == 1)
    }

    @MainActor
    @Test func appStore_editsServerWithoutChangingIdentityOrSelection() throws {
        let suiteName = "byollm-assistantOS.tests.edit-server"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: nil
        )
        store.addName = "Original server"
        store.addUrl = "http://127.0.0.1:9/v1"
        store.saveServer()
        let originalID = try #require(store.servers.first?.id)

        store.beginEditingServer(originalID)
        store.addName = "Renamed server"
        store.addUrl = "http://127.0.0.1:10/v1"
        store.saveServer()

        let edited = try #require(store.servers.first)
        #expect(store.servers.count == 1)
        #expect(edited.id == originalID)
        #expect(edited.name == "Renamed server")
        #expect(edited.url == "http://127.0.0.1:10/v1")
        #expect(edited.active)
        #expect(edited.status == .unknown)
        #expect(store.editingServerID == nil)
        #expect(!store.addOpen)

        let reloadedStore = AppStore(
            defaults: defaults,
            defaultServerConfiguration: nil
        )
        let persisted = try #require(reloadedStore.servers.first)
        #expect(persisted.id == originalID)
        #expect(persisted.name == "Renamed server")
        #expect(persisted.url == "http://127.0.0.1:10/v1")
        #expect(persisted.active)
    }

    @MainActor
    @Test func appStore_loadsSelectsAndRemembersModelsPerServer() async throws {
        let suiteName = "byollm-assistantOS.tests.model-loading"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["model-a", "model-b"])
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)

        store.addName = "Local"
        store.addUrl = "http://127.0.0.1:9/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        #expect(store.models.map(\.name) == ["model-a", "model-b"])
        #expect(store.activeModel == "model-a")
        store.pickModel("model-b")
        #expect(store.activeModel == "model-b")
        #expect(defaults.string(forKey: "mc.model.1") == "model-b")
    }

    @MainActor
    @Test func appStore_loadsAndSelectsServerDefinedHarness() async throws {
        let suiteName = "byollm-assistantOS.tests.dynamic-harness"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let codex = AgentRuntime(rawValue: "codex")
        let network = StubNetworkClient(
            models: ["codex-agent"],
            modelRuntime: codex,
            runtimes: [
                RemoteRuntime(id: "codex", name: "Codex", available: true, model: "codex-agent", unavailableReason: nil),
            ]
        )
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Router"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.harnesses.map(\.name) == ["Codex"] }
        #expect(store.modelLoadState == .empty)
        store.selectRuntime(codex)

        #expect(store.harnesses.map(\.name) == ["Codex"])
        #expect(store.selectedRuntime == codex)
        #expect(store.currentRuntimeName == "Codex")
        #expect(store.activeModel == "codex-agent")
    }

    @MainActor
    @Test func appStore_keepsUnavailableRuntimeSelectedInsteadOfSilentlySwitching() async throws {
        let suiteName = "byollm-assistantOS.tests.unavailable-harness"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AgentRuntime.ohMyPi.rawValue, forKey: "mc.selectedRuntime")
        let network = StubNetworkClient(
            models: ["pi-agent"],
            modelRuntime: .pi,
            runtimes: [
                RemoteRuntime(id: "pi", name: "Pi", available: true, model: "pi-agent", unavailableReason: nil),
                RemoteRuntime(id: "oh-my-pi", name: "Oh My Pi", available: false, model: "oh-my-pi", unavailableReason: "Not configured"),
            ]
        )
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Router"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .empty }

        #expect(store.selectedRuntime == .ohMyPi)
        #expect(store.activeModel.isEmpty)
        #expect(!store.isChatReady)
    }

    @MainActor
    @Test func appStore_omitsGatewayFieldsForGenericOpenAIServer() async throws {
        let suiteName = "byollm-assistantOS.tests.generic-openai"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["generic-model"], runtimes: [], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "OpenAI compatible"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.reasoningEffort = .xhigh
        store.send("Hello")
        await waitUntil { network.hasStreamHandler }

        #expect(network.capturedRuntime == nil)
        #expect(network.capturedReasoningEffort == nil)
        store.stop()
    }

    @MainActor
    @Test func appStore_deletingActiveServerSelectsFallbackAndDeletingLastClearsModels() async throws {
        let suiteName = "byollm-assistantOS.tests.delete-server"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: nil,
            network: StubNetworkClient(models: ["model-a"])
        )

        for index in 1...2 {
            store.addName = "Server \(index)"
            store.addUrl = "http://127.0.0.1:\(8000 + index)/v1"
            store.saveServer()
        }
        await waitUntil { store.modelLoadState == .loaded }
        let firstID = try #require(store.servers.first?.id)
        let secondID = try #require(store.servers.last?.id)

        store.deleteServer(firstID)
        #expect(store.activeServer?.id == secondID)
        await waitUntil { store.modelLoadState == .loaded }
        store.deleteServer(secondID)

        #expect(store.servers.isEmpty)
        #expect(store.models.isEmpty)
        #expect(store.activeModel.isEmpty)
        #expect(!store.isChatReady)
    }

    @MainActor
    @Test func appStore_stopCancelsRequestAndRejectsLateEvents() async throws {
        let suiteName = "byollm-assistantOS.tests.stop-stream"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.reasoningEffort = .high
        store.selectedRuntime = .ohMyPi
        store.send("Run the checks")
        await waitUntil { network.hasStreamHandler }
        let chatID = try #require(store.activeChatId)
        await network.emit(.textDelta("before"))
        await network.emit(.toolStarted(id: "tool-1", name: "read", input: "README.md"))
        await Task.yield()
        store.stop()
        await network.emit(.textDelta("after"))
        await network.emit(.toolFinished(id: "tool-1", name: "read", input: nil, output: "late", isError: false))
        await Task.yield()

        let reply = try #require(store.activeChat?.messages.last)
        #expect(reply.blocks.plainText.contains("before"))
        #expect(!reply.blocks.plainText.contains("after"))
        #expect(!reply.streaming)
        #expect(!store.streaming)
        #expect(store.cancellationSettling)
        await waitUntil(timeoutNanoseconds: 1_500_000_000) { !store.cancellationSettling }
        #expect(store.isChatReady)
        #expect(!store.isChatReadyForAttention(chatID: chatID))
        #expect(network.capturedRuntime == "oh-my-pi")
        #expect(network.capturedReasoningEffort == "high")
        #expect(reply.blocks.contains(where: {
            if case .tool(let tool) = $0 { return tool.id == "tool-1" && tool.status == .cancelled }
            return false
        }))
    }

    @MainActor
    @Test func appStore_runsChatsConcurrentlyAndStopsOnlyTheVisibleConversation() async throws {
        let suiteName = "byollm-assistantOS.tests.concurrent-streams"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.send("Conversation A")
        await waitUntil { network.streamHandlerCount == 1 }
        let chatA = try #require(store.activeChatId)

        store.newChat()
        store.send("Conversation B")
        await waitUntil { network.streamHandlerCount == 2 }
        let chatB = try #require(store.activeChatId)

        #expect(chatA != chatB)
        #expect(store.isGenerating(chatID: chatA))
        #expect(store.isGenerating(chatID: chatB))

        await network.emit(.textDelta("alpha"), at: 0)
        await network.emit(.textDelta("bravo"), at: 1)
        await waitUntil {
            store.chats.first(where: { $0.id == chatA })?.messages.last?.blocks.plainText.contains("alpha") == true
                && store.chats.first(where: { $0.id == chatB })?.messages.last?.blocks.plainText.contains("bravo") == true
        }

        let firstA = try #require(store.chats.first(where: { $0.id == chatA })?.messages.last?.blocks.plainText)
        let firstB = try #require(store.chats.first(where: { $0.id == chatB })?.messages.last?.blocks.plainText)
        #expect(!firstA.contains("bravo"))
        #expect(!firstB.contains("alpha"))

        store.openChat(chatA)
        store.stop()
        #expect(!store.isGenerating(chatID: chatA))
        #expect(store.isGenerating(chatID: chatB))
        #expect(store.cancellationSettling)

        store.openChat(chatB)
        #expect(!store.cancellationSettling)
        await network.emit(.textDelta(" late-alpha"), at: 0)
        await network.emit(.textDelta(" more-bravo"), at: 1)
        await waitUntil {
            store.chats.first(where: { $0.id == chatB })?.messages.last?.blocks.plainText.contains("more-bravo") == true
        }

        let finalA = try #require(store.chats.first(where: { $0.id == chatA })?.messages.last?.blocks.plainText)
        let finalB = try #require(store.chats.first(where: { $0.id == chatB })?.messages.last?.blocks.plainText)
        #expect(!finalA.contains("late-alpha"))
        #expect(finalB.contains("more-bravo"))
        #expect(store.isGenerating(chatID: chatB))

        store.stop()
    }

    @MainActor
    @Test func appStore_marksOnlyCompletedBackgroundChatsReadyForAttention() async throws {
        let suiteName = "byollm-assistantOS.tests.background-chat-ready"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.send("Conversation A")
        await waitUntil { network.streamHandlerCount == 1 }
        let chatA = try #require(store.activeChatId)
        store.newChat()
        store.send("Conversation B")
        await waitUntil { network.streamHandlerCount == 2 }
        let chatB = try #require(store.activeChatId)

        #expect(store.isGenerating(chatID: chatA))
        #expect(store.isGenerating(chatID: chatB))
        #expect(!store.isChatReadyForAttention(chatID: chatA))
        #expect(!store.isChatReadyForAttention(chatID: chatB))
        #expect(network.capturedMessageRoles.first == ["user"])

        network.completeStream(at: 0)
        await waitUntil { !store.isGenerating(chatID: chatA) }
        #expect(store.isChatReadyForAttention(chatID: chatA))
        #expect(store.isGenerating(chatID: chatB))

        network.completeStream(at: 1)
        await waitUntil { !store.isGenerating(chatID: chatB) }
        #expect(!store.isChatReadyForAttention(chatID: chatB))

        store.openChat(chatA)
        #expect(!store.isChatReadyForAttention(chatID: chatA))
    }

    @MainActor
    @Test func appStore_failedBackgroundStreamsNeverBecomeReadyForAttention() async throws {
        let suiteName = "byollm-assistantOS.tests.background-chat-failure"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.send("Structured failure")
        await waitUntil { network.streamHandlerCount == 1 }
        let structuredFailureChat = try #require(store.activeChatId)
        store.newChat()
        await network.emit(.failure("runtime stopped"), at: 0)
        network.completeStream(at: 0)
        await waitUntil { !store.isGenerating(chatID: structuredFailureChat) }

        #expect(!store.isChatReadyForAttention(chatID: structuredFailureChat))
        #expect(
            store.chats.first(where: { $0.id == structuredFailureChat })?
                .messages.last?.blocks.plainText.contains("runtime stopped") == true
        )

        store.send("Transport failure")
        await waitUntil { network.streamHandlerCount == 2 }
        let transportFailureChat = try #require(store.activeChatId)
        store.newChat()
        await network.emit(.textDelta("Final buffered text"), at: 1)
        network.failStream(at: 1)
        await waitUntil { !store.isGenerating(chatID: transportFailureChat) }

        #expect(!store.isChatReadyForAttention(chatID: transportFailureChat))
        let failedText = try #require(
            store.chats.first(where: { $0.id == transportFailureChat })?
                .messages.last?.blocks.plainText
        )
        let bufferedTextRange = try #require(failedText.range(of: "Final buffered text"))
        let errorRange = try #require(failedText.range(of: "[error:"))
        #expect(bufferedTextRange.lowerBound < errorRange.lowerBound)

        store.send("Server cancellation")
        await waitUntil { network.streamHandlerCount == 3 }
        let cancelledChat = try #require(store.activeChatId)
        store.newChat()
        await network.emit(
            .toolStarted(id: "cancelled-tool", name: "search", input: "query"),
            at: 2
        )
        await network.emit(.cancelled, at: 2)
        await waitUntil { !store.isGenerating(chatID: cancelledChat) }

        #expect(!store.isChatReadyForAttention(chatID: cancelledChat))
        #expect(
            store.chats.first(where: { $0.id == cancelledChat })?
                .messages.last?.blocks.contains(where: {
                    guard case .tool(let tool) = $0 else { return false }
                    return tool.id == "cancelled-tool" && tool.status == .cancelled
                }) == true
        )
    }

    @MainActor
    @Test func appStore_startingNewRunClearsReadyForAttention() async throws {
        let suiteName = "byollm-assistantOS.tests.ready-cleared-by-new-run"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.send("First run")
        await waitUntil { network.streamHandlerCount == 1 }
        let chatID = try #require(store.activeChatId)
        store.openDrawer()
        network.completeStream(at: 0)
        await waitUntil { !store.isGenerating(chatID: chatID) }
        #expect(store.isChatReadyForAttention(chatID: chatID))

        store.send("Follow-up run")
        await waitUntil { network.streamHandlerCount == 2 }

        #expect(store.isGenerating(chatID: chatID))
        #expect(!store.isChatReadyForAttention(chatID: chatID))
        store.stop()
    }

    @MainActor
    @Test func appStore_preservesTextToolCodeAndTrailingTextOrder() async throws {
        let suiteName = "byollm-assistantOS.tests.stream-block-order"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }

        store.send("Render a mixed response")
        await waitUntil { network.streamHandlerCount == 1 }
        let chatID = try #require(store.activeChatId)

        await network.emit(.textDelta("Before tool."), at: 0)
        await network.emit(.toolStarted(id: "tool-1", name: "read", input: "README.md"), at: 0)
        await network.emit(
            .toolUpdated(
                id: "tool-1",
                name: "read_file",
                input: "Docs/README.md",
                output: "partial"
            ),
            at: 0
        )
        await network.emit(
            .toolFinished(
                id: "tool-1",
                name: nil,
                input: nil,
                output: nil,
                isError: false
            ),
            at: 0
        )
        await network.emit(.textDelta("After tool.\n```swift"), at: 0)
        await network.emit(.textDelta("\nlet value = 1\n```\nDone"), at: 0)
        network.completeStream(at: 0)
        await waitUntil { !store.isGenerating(chatID: chatID) }

        let reply = try #require(
            store.chats.first(where: { $0.id == chatID })?.messages.last
        )
        #expect(
            reply.blocks == [
                .text("Before tool."),
                .tool(ToolCallBlock(
                    id: "tool-1",
                    name: "read_file",
                    input: "Docs/README.md",
                    output: "partial",
                    status: .succeeded
                )),
                .text("After tool.\n"),
                .code(lang: "swift", text: "let value = 1"),
                .text("\nDone"),
            ]
        )
        #expect(!reply.streaming)
    }

    @MainActor
    @Test func appStore_deletingServerCancelsOnlyItsInflightRuns() async throws {
        let suiteName = "byollm-assistantOS.tests.delete-server-stream"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(models: ["pi-agent"], holdsStreamOpen: true)
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: network)
        store.addName = "Gateway"
        store.addUrl = "http://127.0.0.1:31000/v1"
        store.saveServer()
        await waitUntil { store.modelLoadState == .loaded }
        let serverID = try #require(store.activeServer?.id)

        store.send("Long running work")
        await waitUntil { network.streamHandlerCount == 1 }
        let chatID = try #require(store.activeChatId)
        #expect(store.isGenerating(chatID: chatID))

        store.deleteServer(serverID)

        #expect(!store.isGenerating(chatID: chatID))
        #expect(store.chats.first(where: { $0.id == chatID })?.messages.last?.streaming == false)
        #expect(store.servers.isEmpty)
    }

    @MainActor
    @Test func appStore_startsWithoutFabricatedConnectionsAndPersistsReasoningEffort() throws {
        let suiteName = "byollm-assistantOS.tests.real-connections"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: StubNetworkClient())

        #expect(store.connections.isEmpty)
        #expect(store.connSummary == "None connected")
        store.reasoningEffort = .xhigh
        let reloaded = AppStore(defaults: defaults, defaultServerConfiguration: nil, network: StubNetworkClient())
        #expect(reloaded.reasoningEffort == .xhigh)
    }

    @MainActor
    @Test func appStore_loadsVerifiedGitHubConnectionAndRepositoriesFromActiveServer() async throws {
        let suiteName = "byollm-assistantOS.tests.github-connection"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            connections: [AppConnection(
                id: "github",
                name: "GitHub",
                desc: "Verified by the server",
                account: "octocat",
                connected: true
            )],
            repositories: [GitHubRepository(
                id: 7,
                fullName: "openaccess-ai-collective/monolith",
                isPrivate: true,
                defaultBranch: "main"
            )]
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(id: "test", name: "Test", url: "http://127.0.0.1:31000"),
            network: network
        )

        await waitUntil { store.connectionLoadState == .loaded }
        store.refreshGitHubRepositories()
        await waitUntil { store.repositoryLoadState == .loaded }

        #expect(store.connections.first?.account == "octocat")
        #expect(store.connSummary == "GitHub")
        #expect(store.githubRepositories.first?.fullName == "openaccess-ai-collective/monolith")
        store.selectRepository("openaccess-ai-collective/monolith")
        #expect(store.npRepo == "openaccess-ai-collective/monolith")
    }

    @MainActor
    @Test func appStore_connectionRefreshRejectsLateRepositoryResponse() async throws {
        let suiteName = "byollm-assistantOS.tests.github-repository-race"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            connections: [AppConnection(id: "github", name: "GitHub", desc: "Verified", account: "octocat", connected: true)],
            repositories: [GitHubRepository(id: 7, fullName: "openaccess-ai-collective/monolith", isPrivate: true, defaultBranch: "main")],
            repositoryDelayNanoseconds: 200_000_000
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(id: "test", name: "Test", url: "http://127.0.0.1:31000"),
            network: network
        )
        await waitUntil { store.connectionLoadState == .loaded }

        store.refreshGitHubRepositories()
        #expect(store.repositoryLoadState == .loading)
        store.npRepo = "openaccess-ai-collective/monolith"
        store.refreshConnections()
        #expect(store.npRepo == nil)
        await waitUntil { store.connectionLoadState == .loaded }
        try? await Task.sleep(nanoseconds: 300_000_000)

        #expect(store.githubRepositories.isEmpty)
        #expect(store.repositoryLoadState == .idle)
    }

    @MainActor
    @Test func appStore_connectsGitHubFromClientOAuthCallback() async throws {
        let suiteName = "byollm-assistantOS.tests.github-client-oauth"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authorization = StubGitHubAuthorization(
            callback: try #require(URL(string: "monolith://oauth/github?code=temporary-code&state=expected-state"))
        )
        let network = StubNetworkClient(
            githubOAuthResult: ConnectionAuthorizationResult(
                installationRequired: false,
                installationURL: nil,
                account: "octocat"
            )
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: authorization
        )
        await waitUntil { store.connectionLoadState == .loaded }
        let connectionRequestsBeforeOAuth = network.connectionRequestCount

        store.openAddConn()
        store.connectConnection("github")
        await waitUntil { store.repositoryConnected && store.githubAuthorizationState == .idle }

        #expect(authorization.requestedURL?.host == "github.com")
        #expect(network.githubOAuthCompletions == [
            CapturedGitHubCompletion(flowID: "flow-id", state: "expected-state", code: "temporary-code")
        ])
        #expect(network.connectionRequestCount == connectionRequestsBeforeOAuth)
        #expect(store.connections.first(where: { $0.id == "github" })?.account == "octocat")
        #expect(store.repositoryConnected)
        #expect(!store.addConnOpen)
    }

    @MainActor
    @Test func appStore_routesUnknownConnectionPluginThroughGenericContract() async throws {
        let suiteName = "byollm-assistantOS.tests.generic-connection-plugin"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authorization = StubGitHubAuthorization(
            callback: try #require(URL(string: "monolith://oauth/gitlab?code=temporary-code&state=expected-state"))
        )
        let network = StubNetworkClient(
            connections: [AppConnection(
                id: "gitlab",
                name: "GitLab",
                desc: "Repository access",
                account: "",
                connected: false,
                available: true,
                capabilities: ["authorization", "repositories", "disconnect"]
            )],
            githubOAuthStart: ConnectionAuthorizationStart(
                flowID: "flow-id",
                authorizationURL: try #require(URL(string: "https://gitlab.com/oauth/authorize?state=expected-state")),
                state: "expected-state",
                redirectURI: try #require(URL(string: "monolith://oauth/gitlab")),
                connectionID: "gitlab"
            ),
            githubOAuthResult: ConnectionAuthorizationResult(
                installationRequired: false,
                installationURL: nil,
                account: "team",
                connectionID: "gitlab"
            )
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: authorization
        )
        await waitUntil { store.connectionLoadState == .loaded }

        store.openAddConn("gitlab")
        store.connectConnection()
        await waitUntil { store.repositoryConnected && store.githubAuthorizationState == .idle }

        #expect(network.connectionAuthorizationRequests == ["gitlab"])
        #expect(store.connections.first(where: { $0.id == "gitlab" })?.account == "team")
        #expect(!store.addConnOpen)
    }

    @MainActor
    @Test func appStore_persistsProjectRepositoryPluginAndServerProvenance() async throws {
        let suiteName = "byollm-assistantOS.tests.project-repository-plugin"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gitlab = AppConnection(
            id: "gitlab",
            name: "GitLab",
            desc: "Repository access",
            account: "team",
            connected: true,
            capabilities: ["repositories"]
        )
        let github = AppConnection(
            id: "github",
            name: "GitHub",
            desc: "Repository access",
            account: "octocat",
            connected: true,
            capabilities: ["repositories"]
        )
        let network = StubNetworkClient(
            models: ["pi-agent"],
            modelRuntime: .pi,
            connections: [github, gitlab],
            repositories: [ConnectionRepository(
                id: "project-1",
                connectionID: "gitlab",
                fullName: "team/project",
                isPrivate: true,
                defaultBranch: "main"
            )]
        )
        let server = DefaultServerConfiguration(
            id: "test",
            name: "Test",
            url: "http://127.0.0.1:31000"
        )
        let store = AppStore(defaults: defaults, defaultServerConfiguration: server, network: network)
        await waitUntil { store.connectionLoadState == .loaded }
        await waitUntil { store.modelLoadState == .loaded }

        store.openNewProject()
        store.selectRepositoryConnection("gitlab")
        store.refreshGitHubRepositories()
        await waitUntil { store.repositoryLoadState == .loaded }
        store.selectRepository("team/project")
        store.npName = "Plugin project"
        store.createProject()

        let project = try #require(store.projects.first)
        #expect(project.repo == "team/project")
        #expect(project.repositoryConnectionID == "gitlab")
        #expect(project.repositoryConnectionName == "GitLab")
        #expect(project.repositoryServerID == store.activeServer?.id)
        #expect(project.repositoryServerURL == "http://127.0.0.1:31000")

        store.newChat(inProject: project.id)
        store.send("Inspect the linked repository")
        await waitUntil { network.capturedSystemPrompt != nil }
        #expect(network.capturedSystemPrompt?.contains("Linked repository: team/project") == true)
        #expect(network.capturedSystemPrompt?.contains("Connection plugin: gitlab") == true)
        #expect(store.projects.first?.chatIds.count == 1)

        store.beginAddingServer()
        store.addName = "Other"
        store.addUrl = "http://127.0.0.1:32000"
        store.saveServer()
        let otherServerID = try #require(store.servers.first(where: { !$0.active })?.id)
        store.selectServer(otherServerID)
        await waitUntil { store.modelLoadState == .loaded }
        store.send("Try from another server")
        await waitUntil { network.capturedSystemPrompts.count == 2 }
        #expect(network.capturedSystemPrompts.last?.contains("different Monolith server") == true)
        #expect(network.capturedSystemPrompts.last?.contains("Linked repository: team/project") == false)

        let reloaded = AppStore(defaults: defaults, defaultServerConfiguration: server, network: network)
        let persisted = try #require(reloaded.projects.first)
        #expect(persisted.repo == "team/project")
        #expect(persisted.repositoryConnectionID == "gitlab")
        #expect(persisted.repositoryServerID == project.repositoryServerID)
        #expect(persisted.repositoryServerURL == project.repositoryServerURL)
    }

    @MainActor
    @Test func appStore_rejectsRepositoryFromDifferentPlugin() async throws {
        let suiteName = "byollm-assistantOS.tests.project-repository-plugin-mismatch"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            connections: [AppConnection(
                id: "gitlab",
                name: "GitLab",
                desc: "Repository access",
                account: "team",
                connected: true,
                capabilities: ["repositories"]
            )],
            repositories: [ConnectionRepository(
                id: "wrong-provider",
                connectionID: "github",
                fullName: "other/project",
                isPrivate: false,
                defaultBranch: "main"
            )]
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network
        )
        await waitUntil { store.connectionLoadState == .loaded }

        store.refreshGitHubRepositories()
        await waitUntil {
            if case .failed = store.repositoryLoadState { return true }
            return false
        }
        store.selectRepository("other/project")
        store.npName = "Rejected link"
        store.createProject()

        #expect(store.projects.first?.repo == nil)
        #expect(store.projects.first?.repositoryConnectionID == nil)
    }

    @MainActor
    @Test func appStore_appliesInstallationRequiredOAuthResultWithoutConnectionRefresh() async throws {
        let suiteName = "byollm-assistantOS.tests.github-oauth-installation-result"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            githubOAuthResult: ConnectionAuthorizationResult(
                installationRequired: true,
                installationURL: URL(string: "https://github.com/apps/monolith/installations/new")!,
                account: "octocat"
            )
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: StubGitHubAuthorization(
                callback: try #require(URL(string: "monolith://oauth/github?code=temporary-code&state=expected-state"))
            )
        )
        await waitUntil { store.connectionLoadState == .loaded }
        let connectionRequestsBeforeOAuth = network.connectionRequestCount

        store.connectConnection("github")
        await waitUntil {
            if case .installationRequired = store.githubAuthorizationState { return true }
            return false
        }

        let github = store.connections.first(where: { $0.id == "github" })
        #expect(network.connectionRequestCount == connectionRequestsBeforeOAuth)
        #expect(github?.connected == true)
        #expect(github?.account == "octocat")
        #expect(github?.installationRequired == true)
        #expect(!store.repositoryConnected)
    }

    @MainActor
    @Test func appStore_coalescesRepositoryRefreshWhileLoading() async throws {
        let suiteName = "byollm-assistantOS.tests.github-repository-refresh-coalescing"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            connections: [AppConnection(
                id: "github",
                name: "GitHub",
                desc: "Connected",
                account: "octocat",
                connected: true
            )],
            repositories: [GitHubRepository(
                id: 7,
                fullName: "openaccess-ai-collective/monolith",
                isPrivate: true,
                defaultBranch: "main"
            )],
            repositoryDelayNanoseconds: 200_000_000
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network
        )
        await waitUntil { store.connectionLoadState == .loaded }

        store.refreshGitHubRepositories()
        store.refreshGitHubRepositories()
        #expect(store.repositoryLoadState == .loading)
        await waitUntil { store.repositoryLoadState == .loaded }

        #expect(network.repositoryRequestCount == 1)
        #expect(store.githubRepositories.first?.fullName == "openaccess-ai-collective/monolith")
    }

    @MainActor
    @Test func appStore_rejectsGitHubOAuthStateMismatchBeforeTokenExchange() async throws {
        let suiteName = "byollm-assistantOS.tests.github-state-mismatch"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authorization = StubGitHubAuthorization(
            callback: try #require(URL(string: "monolith://oauth/github?code=temporary-code&state=wrong-state"))
        )
        let network = StubNetworkClient()
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: authorization
        )

        store.connectConnection("github")
        await waitUntil {
            if case .failed = store.githubAuthorizationState { return true }
            return false
        }

        #expect(network.githubOAuthCompletions.isEmpty)
    }

    @MainActor
    @Test func appStore_rejectsHostileGitHubInstallationURL() async throws {
        let suiteName = "byollm-assistantOS.tests.github-hostile-installation"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            githubOAuthResult: ConnectionAuthorizationResult(
                installationRequired: true,
                installationURL: URL(string: "https://evil.example/apps/monolith/installations/new")!
            )
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: StubGitHubAuthorization(
                callback: try #require(URL(string: "monolith://oauth/github?code=temporary-code&state=expected-state"))
            )
        )

        store.openAddConn()
        store.connectConnection("github")
        await waitUntil {
            if case .failed = store.githubAuthorizationState { return true }
            return false
        }

        #expect(store.addConnOpen)
        #expect(!store.repositoryConnected)
    }

    @MainActor
    @Test func appStore_rejectsMissingGitHubInstallationURL() async throws {
        let suiteName = "byollm-assistantOS.tests.github-missing-installation"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(
            githubOAuthResult: ConnectionAuthorizationResult(installationRequired: true, installationURL: nil)
        )
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: StubGitHubAuthorization(
                callback: try #require(URL(string: "monolith://oauth/github?code=temporary-code&state=expected-state"))
            )
        )

        store.openAddConn()
        store.connectConnection("github")
        await waitUntil {
            if case .failed = store.githubAuthorizationState { return true }
            return false
        }

        #expect(store.addConnOpen)
        #expect(!store.repositoryConnected)
    }

    @MainActor
    @Test func appStore_disconnectedRefreshClearsGitHubStateAndRepositorySelection() async throws {
        let suiteName = "byollm-assistantOS.tests.github-disconnected-refresh"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let network = StubNetworkClient(connections: [AppConnection(
            id: "github",
            name: "GitHub",
            desc: "Install the app",
            account: "octocat",
            connected: true,
            installationRequired: true,
            installationURL: "https://github.com/apps/monolith/installations/new"
        )])
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network
        )
        await waitUntil {
            if case .installationRequired = store.githubAuthorizationState { return true }
            return false
        }
        store.npRepo = "owner/stale"

        network.setConnections([AppConnection(
            id: "github",
            name: "GitHub",
            desc: "Not connected",
            account: "",
            connected: false
        )])
        store.refreshConnections()
        await waitUntil { store.connectionLoadState == .loaded }

        #expect(store.githubAuthorizationState == .idle)
        #expect(store.npRepo == nil)
        #expect(!store.repositoryConnected)
    }

    @MainActor
    @Test func appStore_canceledOAuthCannotCompleteOrOverwriteNewAttempt() async throws {
        let suiteName = "byollm-assistantOS.tests.github-canceled-attempt"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authorization = ControlledGitHubAuthorization()
        let network = StubNetworkClient(connections: [AppConnection(
            id: "github",
            name: "GitHub",
            desc: "Connected",
            account: "octocat",
            connected: true
        )])
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: authorization
        )

        store.openAddConn()
        store.connectConnection("github")
        await waitUntil { authorization.pendingCount == 1 }
        store.dismissAddConnection()
        store.openAddConn()
        store.connectConnection("github")
        await waitUntil { authorization.pendingCount == 2 }

        authorization.resume(
            attempt: 0,
            with: try #require(URL(string: "monolith://oauth/github?code=old-code&state=expected-state"))
        )
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(network.githubOAuthCompletions.isEmpty)
        #expect(store.githubAuthorizationState == .authorizing)

        authorization.resume(
            attempt: 1,
            with: try #require(URL(string: "monolith://oauth/github?code=new-code&state=expected-state"))
        )
        await waitUntil { network.githubOAuthCompletions.count == 1 }

        #expect(network.githubOAuthCompletions.first?.code == "new-code")
        #expect(store.githubAuthorizationState == .idle)
    }

    @MainActor
    @Test func appStore_serverSwitchInvalidatesPendingGitHubOAuth() async throws {
        let suiteName = "byollm-assistantOS.tests.github-server-switch"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let authorization = ControlledGitHubAuthorization()
        let network = StubNetworkClient()
        let store = AppStore(
            defaults: defaults,
            defaultServerConfiguration: DefaultServerConfiguration(
                id: "test",
                name: "Test",
                url: "http://127.0.0.1:31000"
            ),
            network: network,
            githubAuthorization: authorization
        )
        store.beginAddingServer()
        store.addName = "Other"
        store.addUrl = "http://127.0.0.1:32000"
        store.saveServer()
        let otherServerID = try #require(store.servers.first(where: { !$0.active })?.id)

        store.connectConnection("github")
        await waitUntil { authorization.pendingCount == 1 }
        store.selectServer(otherServerID)
        authorization.resume(
            attempt: 0,
            with: try #require(URL(string: "monolith://oauth/github?code=old-code&state=expected-state"))
        )
        try? await Task.sleep(nanoseconds: 30_000_000)

        #expect(store.activeServer?.id == otherServerID)
        #expect(network.githubOAuthCompletions.isEmpty)
        #expect(store.githubAuthorizationState == .idle)
    }

    @MainActor
    private func waitUntil(
        timeoutNanoseconds: UInt64 = 5_000_000_000,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while !condition(), DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class StubNetworkClient: MonolithNetworkClient, @unchecked Sendable {
    private let models: [String]
    private let modelRuntime: AgentRuntime?
    private let runtimes: [RemoteRuntime]
    private let holdsStreamOpen: Bool
    private var connectionValues: [AppConnection]
    private let repositories: [GitHubRepository]
    private let repositoryDelayNanoseconds: UInt64
    private let githubOAuthStart: ConnectionAuthorizationStart
    private let githubOAuthResult: ConnectionAuthorizationResult
    private let lock = NSLock()
    private var eventHandlers: [(@Sendable (ChatStreamEvent) async -> Void)] = []
    private var streamGates: [ControlledStreamGate] = []
    private var capturedMessageRoleValues: [[String]] = []
    private var capturedGitHubCompletionValues: [CapturedGitHubCompletion] = []
    private var connectionAuthorizationRequestValues: [String] = []
    private var connectionRequestValue = 0
    private var repositoryRequestValue = 0
    private var capturedSystemPromptValues: [String] = []
    private(set) var capturedRuntime: String?
    private(set) var capturedReasoningEffort: String?
    private(set) var capturedSystemPrompt: String?

    init(
        models: [String] = [],
        modelRuntime: AgentRuntime? = nil,
        runtimes: [RemoteRuntime] = HarnessDescriptor.builtIns.map {
            RemoteRuntime(id: $0.id, name: $0.name, available: $0.available, model: $0.model, unavailableReason: $0.unavailableReason)
        },
        holdsStreamOpen: Bool = false,
        connections: [AppConnection] = [],
        repositories: [GitHubRepository] = [],
        repositoryDelayNanoseconds: UInt64 = 0,
        githubOAuthStart: ConnectionAuthorizationStart? = nil,
        githubOAuthResult: ConnectionAuthorizationResult = ConnectionAuthorizationResult(
            installationRequired: false,
            installationURL: nil
        )
    ) {
        self.models = models
        self.modelRuntime = modelRuntime
        self.runtimes = runtimes
        self.holdsStreamOpen = holdsStreamOpen
        self.connectionValues = connections
        self.repositories = repositories
        self.repositoryDelayNanoseconds = repositoryDelayNanoseconds
        self.githubOAuthStart = githubOAuthStart ?? ConnectionAuthorizationStart(
            flowID: "flow-id",
            authorizationURL: URL(string: "https://github.com/login/oauth/authorize?state=expected-state")!,
            state: "expected-state",
            redirectURI: URL(string: "monolith://oauth/github")!
        )
        self.githubOAuthResult = githubOAuthResult
    }

    var hasStreamHandler: Bool {
        lock.withLock { !eventHandlers.isEmpty }
    }

    var streamHandlerCount: Int {
        lock.withLock { eventHandlers.count }
    }

    var capturedMessageRoles: [[String]] {
        lock.withLock { capturedMessageRoleValues }
    }

    var githubOAuthCompletions: [CapturedGitHubCompletion] {
        lock.withLock { capturedGitHubCompletionValues }
    }

    var connectionRequestCount: Int {
        lock.withLock { connectionRequestValue }
    }

    var connectionAuthorizationRequests: [String] {
        lock.withLock { connectionAuthorizationRequestValues }
    }

    var repositoryRequestCount: Int {
        lock.withLock { repositoryRequestValue }
    }

    var capturedSystemPrompts: [String] {
        lock.withLock { capturedSystemPromptValues }
    }

    func setConnections(_ connections: [AppConnection]) {
        lock.withLock { connectionValues = connections }
    }

    func emit(_ event: ChatStreamEvent) async {
        await lock.withLock { eventHandlers.first }?(event)
    }

    func emit(_ event: ChatStreamEvent, at index: Int) async {
        let handler = lock.withLock {
            eventHandlers.indices.contains(index) ? eventHandlers[index] : nil
        }
        await handler?(event)
    }

    func completeStream(at index: Int) {
        lock.withLock {
            streamGates.indices.contains(index) ? streamGates[index] : nil
        }?.resolve(.success(()))
    }

    func failStream(at index: Int) {
        lock.withLock {
            streamGates.indices.contains(index) ? streamGates[index] : nil
        }?.resolve(.failure(URLError(.networkConnectionLost)))
    }

    func normalizeServerAddress(_ serverAddress: String) throws -> String {
        try NetworkManager.shared.normalizeServerAddress(serverAddress)
    }

    func testConnection(to serverAddress: String, apiToken: String?) async throws -> Bool { true }

    func getModels(from serverAddress: String, apiToken: String?) async throws -> [RemoteModel] {
        models.map { RemoteModel(name: $0, runtime: modelRuntime) }
    }

    func getRuntimes(from serverAddress: String, apiToken: String?) async throws -> [RemoteRuntime] {
        runtimes
    }

    func getConnections(from serverAddress: String, apiToken: String?) async throws -> [AppConnection] {
        lock.withLock {
            connectionRequestValue += 1
            return connectionValues
        }
    }

    func getRepositories(
        for connectionID: String,
        from serverAddress: String,
        apiToken: String?
    ) async throws -> [ConnectionRepository] {
        lock.withLock { repositoryRequestValue += 1 }
        if repositoryDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: repositoryDelayNanoseconds)
        }
        return repositories
    }

    func startConnectionAuthorization(
        for connectionID: String,
        from serverAddress: String,
        apiToken: String?
    ) async throws -> ConnectionAuthorizationStart {
        lock.withLock { connectionAuthorizationRequestValues.append(connectionID) }
        return githubOAuthStart
    }

    func completeConnectionAuthorization(
        for connectionID: String,
        from serverAddress: String,
        apiToken: String?,
        flowID: String,
        state: String,
        code: String
    ) async throws -> ConnectionAuthorizationResult {
        lock.withLock {
            capturedGitHubCompletionValues.append(
                CapturedGitHubCompletion(flowID: flowID, state: state, code: code)
            )
        }
        return githubOAuthResult
    }

    func disconnectConnection(
        _ connectionID: String,
        from serverAddress: String,
        apiToken: String?
    ) async throws {}

    func sendChatMessageStreaming(
        to serverAddress: String,
        model: String,
        messages: [ChatMessage],
        systemPrompt: String?,
        runtime: String?,
        reasoningEffort: String?,
        conversationId: String?,
        apiToken: String?,
        onEvent: @escaping @Sendable (ChatStreamEvent) async -> Void
    ) async throws {
        let gate: ControlledStreamGate? = lock.withLock {
            capturedRuntime = runtime
            capturedReasoningEffort = reasoningEffort
            capturedSystemPrompt = systemPrompt
            capturedSystemPromptValues.append(systemPrompt ?? "")
            capturedMessageRoleValues.append(messages.map(\.role))
            eventHandlers.append(onEvent)
            guard holdsStreamOpen else { return nil }
            let gate = ControlledStreamGate()
            streamGates.append(gate)
            return gate
        }
        try await gate?.wait()
    }
}

private final class ControlledStreamGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?

    func wait() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resolved: Result<Void, Error>? = lock.withLock {
                    if let result { return result }
                    self.continuation = continuation
                    return nil
                }
                if let resolved { continuation.resume(with: resolved) }
            }
        } onCancel: {
            self.resolve(.failure(CancellationError()))
        }
    }

    func resolve(_ result: Result<Void, Error>) {
        let continuation: CheckedContinuation<Void, Error>? = lock.withLock {
            guard self.result == nil else { return nil }
            self.result = result
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}

private struct CapturedGitHubCompletion: Equatable {
    let flowID: String
    let state: String
    let code: String
}

@MainActor
private final class StubGitHubAuthorization: GitHubAuthorizationPresenting {
    let callback: URL
    private(set) var requestedURL: URL?

    init(callback: URL) {
        self.callback = callback
    }

    func authorize(at url: URL, callbackScheme: String) async throws -> URL {
        requestedURL = url
        return callback
    }

    func cancel() {}
}

@MainActor
private final class ControlledGitHubAuthorization: GitHubAuthorizationPresenting {
    private var continuations: [CheckedContinuation<URL, Error>] = []

    var pendingCount: Int { continuations.count }

    func authorize(at url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func cancel() {}

    func resume(attempt: Int, with callback: URL) {
        continuations[attempt].resume(returning: callback)
    }
}
