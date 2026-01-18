import Foundation
import Testing

struct NotesyncDocsTests {
    @Test func readmeMentionsNotesyncEndpoint() async throws {
        let fileURL = URL(fileURLWithPath: #filePath)
        let rootURL = fileURL.deletingLastPathComponent().deletingLastPathComponent()
        let readmeURL = rootURL.appendingPathComponent("README.md")
        let text = try String(contentsOf: readmeURL, encoding: .utf8)
        #expect(text.contains("/api/notesync"))
    }
}
