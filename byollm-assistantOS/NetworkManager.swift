//
//  NetworkManager.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import Foundation
import Network

enum ChatStreamEvent: Equatable, Sendable {
    case textDelta(String)
    case reasoningDelta(String)
    case toolStarted(id: String, name: String, input: String)
    case toolUpdated(id: String, output: String)
    case toolFinished(id: String, output: String, isError: Bool)
    case failure(String)
}

struct RemoteModel: Equatable, Sendable {
    let name: String
    let runtime: AgentRuntime?
}

struct RemoteRuntime: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let available: Bool
    let model: String
    let unavailableReason: String?

    enum CodingKeys: String, CodingKey {
        case id, name, available, model
        case unavailableReason = "unavailable_reason"
    }
}

struct GitHubRepository: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let fullName: String
    let isPrivate: Bool
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case isPrivate = "private"
        case defaultBranch = "default_branch"
    }
}

struct GitHubOAuthStart: Codable, Equatable, Sendable {
    let flowID: String
    let authorizationURL: URL
    let state: String
    let redirectURI: URL

    enum CodingKeys: String, CodingKey {
        case state
        case flowID = "flow_id"
        case authorizationURL = "authorization_url"
        case redirectURI = "redirect_uri"
    }
}

struct GitHubOAuthResult: Codable, Equatable, Sendable {
    let installationRequired: Bool
    let installationURL: URL?
    let account: String?

    init(installationRequired: Bool, installationURL: URL?, account: String? = nil) {
        self.installationRequired = installationRequired
        self.installationURL = installationURL
        self.account = account
    }

    enum CodingKeys: String, CodingKey {
        case account
        case installationRequired = "installation_required"
        case installationURL = "installation_url"
    }
}

protocol MonolithNetworkClient {
    func normalizeServerAddress(_ serverAddress: String) throws -> String
    func testConnection(to serverAddress: String, apiToken: String?) async throws -> Bool
    func getModels(from serverAddress: String, apiToken: String?) async throws -> [RemoteModel]
    func getRuntimes(from serverAddress: String, apiToken: String?) async throws -> [RemoteRuntime]
    func getConnections(from serverAddress: String, apiToken: String?) async throws -> [AppConnection]
    func getGitHubRepositories(from serverAddress: String, apiToken: String?) async throws -> [GitHubRepository]
    func startGitHubOAuth(from serverAddress: String, apiToken: String?) async throws -> GitHubOAuthStart
    func completeGitHubOAuth(
        from serverAddress: String,
        apiToken: String?,
        flowID: String,
        state: String,
        code: String
    ) async throws -> GitHubOAuthResult
    func disconnectGitHub(from serverAddress: String, apiToken: String?) async throws
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
    ) async throws
}

// MARK: - API Models
struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let provider: String?
    let runtime: String?
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool
    let safetyLevel: String?
    let reasoningEffort: String?
    let conversationId: String?
    let includeReasoning: Bool?  // Request reasoning content in response

    enum CodingKeys: String, CodingKey {
        case model, messages, provider, runtime, temperature, stream
        case maxTokens = "max_tokens"
        case safetyLevel = "safety_level"
        case reasoningEffort = "reasoning_effort"
        case conversationId = "conversation_id"
        case includeReasoning = "include_reasoning"
    }
    
    // Initialize without max_tokens by setting it to nil
    init(
        model: String,
        messages: [ChatMessage],
        provider: String? = nil,
        runtime: String? = nil,
        temperature: Double?,
        stream: Bool,
        safetyLevel: String?,
        reasoningEffort: String? = nil,
        conversationId: String? = nil,
        includeReasoning: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.provider = provider
        self.runtime = runtime
        self.temperature = temperature
        self.maxTokens = nil  // Remove token limit
        self.stream = stream
        self.safetyLevel = safetyLevel
        self.reasoningEffort = reasoningEffort
        self.conversationId = conversationId
        self.includeReasoning = includeReasoning
    }
}

/// Local file/image attachment for multipart chat requests.
struct ChatCompletionFile {
    let filename: String
    let mimeType: String
    let data: Data
}

struct ChatResponse: Codable {
    let id: String
    let object: String
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: ResponseMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct ResponseMessage: Codable {
        let role: String
        let content: String
        let reasoningContent: String?  // For GPT-oss thinking (reasoning_content)
        let reasoning: String?  // For Ollama native reasoning output
        
        enum CodingKeys: String, CodingKey {
            case role, content, reasoning
            case reasoningContent = "reasoning_content"
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct ChatStreamResponse: Codable {
    let id: String
    let object: String
    let model: String
    let choices: [StreamChoice]
    let monolithEvent: MonolithStreamEvent?

    enum CodingKeys: String, CodingKey {
        case id, object, model, choices
        case monolithEvent = "monolith_event"
    }
    
    struct StreamChoice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }
    
    struct Delta: Codable {
        let role: String?
        let content: String?
        let reasoningContent: String?  // For GPT-oss thinking (reasoning_content)
        let reasoning: String?  // For Ollama native reasoning output
        
        enum CodingKeys: String, CodingKey {
            case role, content, reasoning
            case reasoningContent = "reasoning_content"
        }
    }
}

struct MonolithStreamEvent: Codable {
    let type: String
    let id: String?
    let name: String?
    let input: JSONValue?
    let output: JSONValue?
    let isError: Bool?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case type, id, name, input, output, message
        case isError = "is_error"
    }

    var event: ChatStreamEvent? {
        switch type {
        case "tool_started":
            guard let id, let name else { return nil }
            return .toolStarted(id: id, name: name, input: input?.text ?? "")
        case "tool_updated":
            guard let id else { return nil }
            return .toolUpdated(id: id, output: output?.text ?? "")
        case "tool_finished":
            guard let id else { return nil }
            return .toolFinished(id: id, output: output?.text ?? "", isError: isError ?? false)
        case "error":
            return .failure(message ?? output?.text ?? "The runtime failed")
        default:
            return nil
        }
    }
}

enum JSONValue: Codable, Equatable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var text: String {
        if case .string(let value) = self { return value }
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

struct ModelsResponse: Codable {
    let object: String
    let data: [ModelInfo]
    
    struct ModelInfo: Codable {
        let id: String
        let object: String
        let created: Int?
        let ownedBy: String?
        
        enum CodingKeys: String, CodingKey {
            case id, object, created
            case ownedBy = "owned_by"
        }
    }
}

struct ListResponse<Element: Decodable>: Decodable {
    let data: [Element]
}

struct HealthResponse: Codable {
    let status: String
    let backend: String?
    let version: String?
}

private struct GatewayErrorResponse: Decodable {
    struct Detail: Decodable {
        let message: String
    }
    let error: Detail
}

private struct EmptyRequest: Encodable {}

private struct GitHubOAuthCompleteRequest: Encodable {
    let flowID: String
    let state: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case state, code
        case flowID = "flow_id"
    }
}

// MARK: - Network Manager
final class NetworkManager: MonolithNetworkClient {
    static let shared = NetworkManager()

    private func applyAuthorization(_ token: String?, to request: inout URLRequest) {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func get<Response: Decodable>(
        _ path: String,
        from serverAddress: String,
        apiToken: String?,
        requiresSecureTransport: Bool = false
    ) async throws -> Response {
        let baseURL = try validatedServerAddress(
            serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: requiresSecureTransport
        )
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        applyAuthorization(apiToken, to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func post<Response: Decodable, Body: Encodable>(
        _ path: String,
        body: Body,
        to serverAddress: String,
        apiToken: String?,
        requiresSecureTransport: Bool = false,
        timeoutInterval: TimeInterval = 15.0
    ) async throws -> Response {
        let baseURL = try validatedServerAddress(
            serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: requiresSecureTransport
        )
        guard let url = URL(string: "\(baseURL)\(path)") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        applyAuthorization(apiToken, to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let gatewayError = try? JSONDecoder().decode(GatewayErrorResponse.self, from: data) {
                throw NetworkError.connectionFailed(gatewayError.error.message)
            }
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    private init() {}
    
    func normalizeServerAddress(_ serverAddress: String) throws -> String {
        var urlString = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else {
            throw NetworkError.invalidURL
        }

        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            let candidate = URLComponents(string: "https://\(urlString)")
            let host = candidate?.host ?? ""
            let scheme = isLoopbackHost(host) || host.hasSuffix(".local") ? "http" : "https"
            urlString = "\(scheme)://\(urlString)"
        }

        guard var components = URLComponents(string: urlString),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil,
              components.query == nil,
              components.fragment == nil else {
            throw NetworkError.invalidURL
        }

        components.scheme = scheme
        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        if path.lowercased().hasSuffix("/v1") {
            path.removeLast(3)
        }
        components.percentEncodedPath = path

        guard let normalizedURL = components.url else {
            throw NetworkError.invalidURL
        }
        return normalizedURL.absoluteString
    }

    func validatedServerAddress(
        _ serverAddress: String,
        apiToken: String?,
        requiresSecureTransport: Bool = false
    ) throws -> String {
        let normalized = try normalizeServerAddress(serverAddress)
        guard let components = URLComponents(string: normalized),
              let scheme = components.scheme,
              let host = components.host else {
            throw NetworkError.invalidURL
        }
        let hasToken = !(apiToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if (hasToken || requiresSecureTransport), scheme != "https", !isLoopbackHost(host) {
            throw NetworkError.insecureAuthenticatedTransport
        }
        return normalized
    }

    private func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        if normalized == "localhost" || normalized == "::1" || normalized == "[::1]" {
            return true
        }
        guard let address = IPv4Address(normalized) else {
            return false
        }
        return address.rawValue.first == 127
    }

    // Test connection using health endpoint
    func testConnection(to serverAddress: String, apiToken: String? = nil) async throws -> Bool {
        let urlString = try validatedServerAddress(serverAddress, apiToken: apiToken)
        guard let url = URL(string: "\(urlString)/health") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        applyAuthorization(apiToken, to: &request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if (200...299).contains(httpResponse.statusCode) {
                    // Try to decode health response
                    if let healthResponse = try? JSONDecoder().decode(HealthResponse.self, from: data) {
                        return healthResponse.status == "healthy"
                    }
                    return true
                }
            }
            
            return false
        } catch {
            throw NetworkError.connectionFailed(error.localizedDescription)
        }
    }
    
    // Get available models
    func getModels(from serverAddress: String, apiToken: String? = nil) async throws -> [RemoteModel] {
        let decoded: ModelsResponse = try await get("/v1/models", from: serverAddress, apiToken: apiToken)
        return decoded.data.map {
            RemoteModel(name: $0.id, runtime: $0.ownedBy.map(AgentRuntime.init(rawValue:)))
        }
    }

    func getRuntimes(from serverAddress: String, apiToken: String? = nil) async throws -> [RemoteRuntime] {
        let response: ListResponse<RemoteRuntime> = try await get("/v1/runtimes", from: serverAddress, apiToken: apiToken)
        return response.data
    }

    func getConnections(from serverAddress: String, apiToken: String? = nil) async throws -> [AppConnection] {
        let response: ListResponse<AppConnection> = try await get(
            "/v1/connections",
            from: serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: true
        )
        return response.data
    }

    func getGitHubRepositories(from serverAddress: String, apiToken: String? = nil) async throws -> [GitHubRepository] {
        let response: ListResponse<GitHubRepository> = try await get(
            "/v1/github/repositories",
            from: serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: true
        )
        return response.data
    }

    func startGitHubOAuth(from serverAddress: String, apiToken: String? = nil) async throws -> GitHubOAuthStart {
        try await post(
            "/v1/github/oauth/start",
            body: EmptyRequest(),
            to: serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: true
        )
    }

    func completeGitHubOAuth(
        from serverAddress: String,
        apiToken: String? = nil,
        flowID: String,
        state: String,
        code: String
    ) async throws -> GitHubOAuthResult {
        try await post(
            "/v1/github/oauth/complete",
            body: GitHubOAuthCompleteRequest(flowID: flowID, state: state, code: code),
            to: serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: true,
            timeoutInterval: 30.0
        )
    }

    func disconnectGitHub(from serverAddress: String, apiToken: String? = nil) async throws {
        let baseURL = try validatedServerAddress(
            serverAddress,
            apiToken: apiToken,
            requiresSecureTransport: true
        )
        guard let url = URL(string: "\(baseURL)/v1/github/connection") else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 15.0
        applyAuthorization(apiToken, to: &request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }
    
    // MARK: - Chat (JSON or multipart with attachments)
    
    private func buildChatRequest(
        model: String,
        messages: [ChatMessage],
        systemPrompt: String?,
        provider: String?,
        runtime: String? = nil,
        temperature: Double,
        stream: Bool,
        safetyLevel: String?,
        reasoningEffort: String?,
        conversationId: String?
    ) -> ChatRequest {
        var allMessages: [ChatMessage] = []
        if let systemPrompt, !systemPrompt.isEmpty {
            allMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        allMessages.append(contentsOf: messages)
        
        return ChatRequest(
            model: model,
            messages: allMessages,
            provider: provider,
            runtime: runtime,
            temperature: temperature,
            stream: stream,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId,
            includeReasoning: reasoningEffort != nil ? true : nil
        )
    }
    
    private func makeMultipartBody(
        boundary: String,
        payloadJson: String,
        files: [ChatCompletionFile]
    ) -> Data {
        var body = Data()
        
        // payload (required): JSON string
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"payload\"\r\n\r\n".data(using: .utf8)!)
        body.append(payloadJson.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // files (optional, repeated)
        for file in files {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(file.mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(file.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
    
    // Send chat message
    func sendChatMessage(
        to serverAddress: String,
        model: String,
        messages: [ChatMessage],
        files: [ChatCompletionFile] = [],
        systemPrompt: String? = nil,
        provider: String? = nil,
        safetyLevel: String? = nil,
        temperature: Double = 0.7,
        reasoningEffort: String? = nil,
        conversationId: String? = nil
    ) async throws -> String {
        let urlString = try normalizeServerAddress(serverAddress)
        
        guard let url = URL(string: "\(urlString)/v1/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        
        let chatRequest = buildChatRequest(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            provider: provider,
            temperature: temperature,
            stream: false,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId
        )
        
        if files.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(chatRequest)
            
        } else {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let payloadData = try JSONEncoder().encode(chatRequest)
            let payloadJson = String(decoding: payloadData, as: UTF8.self)
            request.httpBody = makeMultipartBody(boundary: boundary, payloadJson: payloadJson, files: files)
            
            print("Sending multipart request with \(files.count) file(s)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw NetworkError.noContent
        }
        
        return content
    }
    
    // Send chat message with streaming
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
        try await sendChatMessageStreaming(
            to: serverAddress,
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            runtime: runtime,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId,
            apiToken: apiToken,
            onChunk: { await onEvent(.textDelta($0)) },
            onReasoningChunk: { await onEvent(.reasoningDelta($0)) },
            onStructuredEvent: onEvent
        )
    }

    func sendChatMessageStreaming(
        to serverAddress: String,
        model: String,
        messages: [ChatMessage],
        files: [ChatCompletionFile] = [],
        systemPrompt: String? = nil,
        provider: String? = nil,
        runtime: String? = nil,
        safetyLevel: String? = nil,
        temperature: Double = 0.7,
        reasoningEffort: String? = nil,
        conversationId: String? = nil,
        apiToken: String? = nil,
        onChunk: @escaping (String) async -> Void,
        onReasoningChunk: @escaping (String) async -> Void = { _ in },
        onStructuredEvent: @escaping @Sendable (ChatStreamEvent) async -> Void = { _ in }
    ) async throws {
        let urlString = try validatedServerAddress(serverAddress, apiToken: apiToken)
        
        guard let url = URL(string: "\(urlString)/v1/chat/completions") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0
        applyAuthorization(apiToken, to: &request)
        
        let chatRequest = buildChatRequest(
            model: model,
            messages: messages,
            systemPrompt: systemPrompt,
            provider: provider,
            runtime: runtime,
            temperature: temperature,
            stream: true,
            safetyLevel: safetyLevel,
            reasoningEffort: reasoningEffort,
            conversationId: conversationId
        )
        
        if files.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(chatRequest)
            
        } else {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let payloadData = try JSONEncoder().encode(chatRequest)
            let payloadJson = String(decoding: payloadData, as: UTF8.self)
            request.httpBody = makeMultipartBody(boundary: boundary, payloadJson: payloadJson, files: files)
            
            print("Sending streaming multipart request with \(files.count) file(s)")
        }
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        for try await rawLine in asyncBytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, line != "data: [DONE]", line.hasPrefix("data: ") else { continue }

            let json = line.dropFirst(6)
            guard let data = String(json).data(using: .utf8) else { continue }
            do {
                let streamResponse = try JSONDecoder().decode(ChatStreamResponse.self, from: data)
                if let event = streamResponse.monolithEvent?.event {
                    await onStructuredEvent(event)
                }
                if let reasoningContent = streamResponse.choices.first?.delta.reasoningContent {
                    await onReasoningChunk(reasoningContent)
                }
                if let reasoning = streamResponse.choices.first?.delta.reasoning {
                    await onReasoningChunk(reasoning)
                }
                if let content = streamResponse.choices.first?.delta.content {
                    await onChunk(content)
                }
            } catch {
                print("⚠️ Failed to parse SSE event: \(error)")
            }
        }
    }
    
    enum NetworkError: LocalizedError {
        case invalidURL
        case connectionFailed(String)
        case invalidResponse
        case serverError(statusCode: Int)
        case noContent
        case insecureAuthenticatedTransport
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server address format"
            case .connectionFailed(let message):
                return "Connection failed: \(message)"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let statusCode):
                return "Server error (status code: \(statusCode))"
            case .noContent:
                return "No content received from server"
            case .insecureAuthenticatedTransport:
                return "Authenticated servers must use HTTPS unless they run on this device."
            }
        }
    }
}
