import Foundation
import Testing
@testable import timeline

struct NotesyncBatcherTests {
    @Test func batcherSplitsOpsUnderLimit() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let batcher = NotesyncBatcher(maxBytes: 512 * 1024, encoder: encoder)
        let note = SyncNotePayload(
            id: "n1",
            text: "hello",
            isPinned: false,
            tags: [],
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
        let media = SyncMediaPayload(
            id: "m1",
            noteId: "n1",
            kind: "image",
            filename: "1.jpg",
            contentType: "image/jpeg",
            checksum: "sum",
            dataBase64: String(repeating: "a", count: 400_000)
        )
        let ops = [
            SyncOperationPayload(opId: "o1", opType: "create", note: note, media: [media]),
            SyncOperationPayload(opId: "o2", opType: "create", note: note, media: [media]),
            SyncOperationPayload(opId: "o3", opType: "create", note: note, media: [media])
        ]

        let batches = try batcher.split(ops: ops)
        #expect(batches.count > 1)
    }
}
