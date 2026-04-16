//
//  MockRealtimeRepository.swift
//  Workspace
//
//  Multicast mock: each call to events() gets its own continuation. Calls to
//  inject() fan out to every live continuation.
//

import Foundation

final class MockRealtimeRepository: RealtimeRepository {

    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<WorkspaceEvent>.Continuation] = [:]

    init() {}

    func events() -> AsyncStream<WorkspaceEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            self.continuations[id] = continuation
            self.lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    func events(forChannel channel: ChannelID) -> AsyncStream<WorkspaceEvent> {
        let upstream = events()
        return AsyncStream { continuation in
            Task {
                for await event in upstream {
                    switch event {
                    case .messageCreated(let cid, _), .messageUpdated(let cid, _):
                        if cid == channel { continuation.yield(event) }
                    default:
                        continuation.yield(event)
                    }
                }
                continuation.finish()
            }
        }
    }

    func inject(_ event: WorkspaceEvent) {
        lock.lock()
        let values = Array(continuations.values)
        lock.unlock()
        for c in values { c.yield(event) }
    }
}
