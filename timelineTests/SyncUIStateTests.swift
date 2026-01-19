import Testing
@testable import timeline

struct SyncUIStateTests {
    @Test func syncStateStartsIdle() async throws {
        let state = NotesyncUIState()
        #expect(state.isSyncing == false)
    }

    @Test func syncIsDisabledWhenSignedOut() async throws {
        let state = NotesyncUIState()
        #expect(state.isSyncDisabled(isSignedIn: false))
    }

    @Test func syncIsEnabledWhenSignedInAndIdle() async throws {
        let state = NotesyncUIState()
        #expect(state.isSyncDisabled(isSignedIn: true) == false)
    }

    @Test func syncIsDisabledWhileSyncing() async throws {
        let state = NotesyncUIState()
        state.isSyncing = true
        #expect(state.isSyncDisabled(isSignedIn: true))
    }
}
