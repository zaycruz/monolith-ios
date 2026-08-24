import AuthenticationServices
import UIKit

private final class GitHubAuthorizationContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?

    init(_ continuation: CheckedContinuation<URL, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<URL, Error>) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}

@MainActor
protocol GitHubAuthorizationPresenting {
    func authorize(at url: URL, callbackScheme: String) async throws -> URL
    func cancel()
}

@MainActor
final class GitHubAuthorizationSession: NSObject, GitHubAuthorizationPresenting, ASWebAuthenticationPresentationContextProviding {
    private struct Attempt {
        let id: UUID
        let session: ASWebAuthenticationSession
    }

    private var activeAttempt: Attempt?

    func authorize(at url: URL, callbackScheme: String) async throws -> URL {
        cancel()
        let attemptID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let continuation = GitHubAuthorizationContinuation(continuation)
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { [weak self] url, error in
                    if self?.activeAttempt?.id == attemptID {
                        self?.activeAttempt = nil
                    }
                    if let url {
                        continuation.resume(with: .success(url))
                    } else if let error = error as? ASWebAuthenticationSessionError,
                              error.code == .canceledLogin {
                        continuation.resume(with: .failure(CancellationError()))
                    } else {
                        continuation.resume(with: .failure(error ?? URLError(.cancelled)))
                    }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                activeAttempt = Attempt(id: attemptID, session: session)
                if !session.start() {
                    if activeAttempt?.id == attemptID {
                        activeAttempt = nil
                    }
                    continuation.resume(with: .failure(URLError(.cannotLoadFromNetwork)))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(attemptID: attemptID) }
        }
    }

    func cancel() {
        guard let attempt = activeAttempt else { return }
        cancel(attemptID: attempt.id)
    }

    private func cancel(attemptID: UUID) {
        guard activeAttempt?.id == attemptID else { return }
        let attempt = activeAttempt
        activeAttempt = nil
        attempt?.session.cancel()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
