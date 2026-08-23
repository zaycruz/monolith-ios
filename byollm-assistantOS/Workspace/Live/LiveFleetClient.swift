//
//  LiveFleetClient.swift
//  Workspace
//
//  Thin async/await HTTP client for the Raava Fleet control-plane API
//  (`MonolithConfig.fleetAPIBaseURL`). The client is transport-only:
//  it performs the request and decodes the JSON body into a `Decodable`
//  type. It does NOT know about domain models — those live in
//  `LiveAgentRepository` and map API shapes to workspace `Agent` values.
//
//  Do NOT hardcode the base URL anywhere outside `MonolithConfig`.
//

import Foundation

/// Typed errors raised by `LiveFleetClient`. Callers can catch specific
/// cases (e.g. `.unauthorized` to force a re-auth) or fall back to a
/// generic error message.
enum FleetAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case server(status: Int, body: String?)
    case decoding(String)
    /// Endpoint exists in the workspace protocol but is not yet supported
    /// by the Fleet API. Used by `LiveAgentRepository` for things like
    /// `invite(...)` until the control plane exposes them.
    case unsupported(String)
}

final class LiveFleetClient: @unchecked Sendable {

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = MonolithConfig.fleetAPIBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let d = JSONDecoder()
        // Fleet API emits snake_case; the Swift models use camelCase.
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    /// GETs `path` (e.g. `/api/containers`) and decodes the body as `T`.
    func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        return try await request(path: path, method: "GET", as: type)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        as type: T.Type
    ) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw FleetAPIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw FleetAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw FleetAPIError.decoding("\(error)")
            }
        case 401:
            throw FleetAPIError.unauthorized
        case 403:
            throw FleetAPIError.forbidden
        case 404:
            throw FleetAPIError.notFound
        default:
            let body = String(data: data, encoding: .utf8)
            throw FleetAPIError.server(status: http.statusCode, body: body)
        }
    }
}
