import Testing
@testable import timeline

struct SyncUIStateTests {
    @Test func syncStateStartsIdle() async throws {
        let state = NotesyncUIState()
        #expect(state.isSyncing == false)
    }
}
