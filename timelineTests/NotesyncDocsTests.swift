import Foundation
import Testing

struct NotesyncDocsTests {
    @Test func readmeMentionsNotesyncEndpoint() async throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let readmeURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("README.md")
        let text = try String(contentsOf: readmeURL, encoding: .utf8)
        #expect(text.contains("/api/notesync"))
    }
}
