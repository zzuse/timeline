import Foundation
import Testing
@testable import timeline

struct SyncQueueTests {
    @Test func enqueueCreateWritesFile() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let note = Note(text: "Hello", imagePaths: [], tags: [])

        try queue.enqueueCreate(note: note, imagePaths: [], audioPaths: [], tags: ["work"])

        let items = try queue.pending()
        #expect(items.count == 1)
        #expect(items[0].opType == .create)
        #expect(items[0].note.id == note.id)
    }
}
