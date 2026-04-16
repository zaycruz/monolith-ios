//
//  RealtimeRepository.swift
//  Workspace
//
//  Realtime fan-out of WorkspaceEvent to subscribers. Async-sequence based
//  so views can iterate events with `for await event in repo.events() { ... }`.
//

import Foundation

protocol RealtimeRepository {
    /// Long-lived stream of workspace-wide events.
    /// The returned AsyncStream should terminate when the consumer is deallocated.
    func events() -> AsyncStream<WorkspaceEvent>

    /// Scoped stream for a single channel. Mocks may filter `events()` internally.
    func events(forChannel id: ChannelID) -> AsyncStream<WorkspaceEvent>

    /// Manually inject an event. Useful for optimistic updates in mocks / tests.
    func inject(_ event: WorkspaceEvent)
}
