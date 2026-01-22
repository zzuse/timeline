import Foundation

final class NotesyncUIState: ObservableObject {
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var lastSyncAt: Date?

    var lastSyncStatusText: String {
        if let lastSyncAt {
            return lastSyncAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Never"
    }

    var lastErrorStatusText: String {
        guard let lastError, !lastError.isEmpty else { return "None" }
        return lastError
    }

    func isSyncDisabled(isSignedIn: Bool) -> Bool {
        isSyncing || !isSignedIn
    }

    func isRestoreDisabled(isSignedIn: Bool) -> Bool {
        isSyncing || !isSignedIn
    }
}
