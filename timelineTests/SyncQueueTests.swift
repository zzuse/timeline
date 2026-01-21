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

    @Test func enqueueCreateUsesSha256Checksum() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let note = Note(text: "Hello", imagePaths: [], tags: [])
        let imagesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        let filename = "test-image-\(UUID().uuidString).jpg"
        let fileURL = imagesURL.appendingPathComponent(filename)
        try Data("hello".utf8).write(to: fileURL, options: .atomic)

        try queue.enqueueCreate(note: note, imagePaths: [filename], audioPaths: [], tags: [])

        let items = try queue.pending()
        let checksum = items.first?.media.first?.checksum
        #expect(checksum == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

}
