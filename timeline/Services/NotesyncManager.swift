import Foundation

final class NotesyncManager {
    private let queue: SyncQueue
    private let client: NotesyncClient
    private let maxRequestBytes: Int
    private let encoder: JSONEncoder
    private let batcher: NotesyncBatching

    init(
        queue: SyncQueue = try! SyncQueue(),
        client: NotesyncClient,
        maxRequestBytes: Int = AppConfiguration.default.notesync.maxRequestBytes,
        batcher: NotesyncBatching? = nil
    ) {
        self.queue = queue
        self.client = client
        self.maxRequestBytes = maxRequestBytes
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        self.batcher = batcher ?? NotesyncBatcher(maxBytes: maxRequestBytes, encoder: encoder)
    }

    func performSync() async throws {
        let pending = try queue.pending()
        guard !pending.isEmpty else { return }
        let payload = try buildPayload(from: pending)
        let itemById = Dictionary(uniqueKeysWithValues: pending.map { ($0.opId, $0) })
        for batch in try batcher.split(ops: payload.ops) {
            _ = try await client.send(payload: SyncRequest(ops: batch))
            let sentItems = batch.compactMap { itemById[$0.opId] }
            try queue.remove(items: sentItems)
        }
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
