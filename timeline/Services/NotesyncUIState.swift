import Foundation

final class NotesyncUIState: ObservableObject {
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var lastSyncAt: Date?

    func isSyncDisabled(isSignedIn: Bool) -> Bool {
        isSyncing || !isSignedIn
    }
}
