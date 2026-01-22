import Foundation

enum NotesyncBatchingError: Error {
    case opTooLarge
}

struct NotesyncBatcher {
    let maxBytes: Int
    let encoder: JSONEncoder

    func split(ops: [SyncOperationPayload]) throws -> [[SyncOperationPayload]] {
        var batches: [[SyncOperationPayload]] = []
        var current: [SyncOperationPayload] = []
        for op in ops {
            let candidate = current + [op]
            let size = try encoder.encode(SyncRequest(ops: candidate)).count
            if size <= maxBytes {
                current = candidate
                continue
            }
            if current.isEmpty {
                throw NotesyncBatchingError.opTooLarge
            }
            batches.append(current)
            current = [op]
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }
}
