import Foundation

final class NotesyncManager {
    private let queue: SyncQueue
    private let client: NotesyncClient

    init(queue: SyncQueue = try! SyncQueue(), client: NotesyncClient) {
        self.queue = queue
        self.client = client
    }

    func performSync() async throws {
        let pending = try queue.pending()
        guard !pending.isEmpty else { return }
        let payload = try buildPayload(from: pending)
        _ = try await client.send(payload: payload)
        try queue.remove(items: pending)
    }

    private func buildPayload(from items: [SyncQueueItem]) throws -> SyncRequest {
        let ops = try items.map { item -> SyncOperationPayload in
            let media = try item.media.map { media in
                let data = try loadQueueMedia(relativePath: media.localPath)
                return SyncMediaPayload(
                    id: media.id,
                    noteId: media.noteId,
                    kind: media.kind,
                    filename: media.filename,
                    contentType: media.contentType,
                    checksum: media.checksum,
                    dataBase64: data.base64EncodedString()
                )
            }
            return SyncOperationPayload(
                opId: item.opId,
                opType: item.opType.rawValue,
                note: SyncNotePayload(
                    id: item.note.id,
                    text: item.note.text,
                    isPinned: item.note.isPinned,
                    tags: item.note.tags,
                    createdAt: item.note.createdAt,
                    updatedAt: item.note.updatedAt,
                    deletedAt: item.note.deletedAt
                ),
                media: media
            )
        }
        return SyncRequest(ops: ops)
    }

    private func loadQueueMedia(relativePath: String) throws -> Data {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = root.appendingPathComponent("SyncQueue/Media").appendingPathComponent(relativePath)
        return try Data(contentsOf: url)
    }
}
