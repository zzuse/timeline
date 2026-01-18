import Testing

struct NotesyncDocsTests {
    @Test func readmeMentionsNotesyncEndpoint() async throws {
        let text = try String(contentsOfFile: "README.md", encoding: .utf8)
        #expect(text.contains("/api/notesync"))
    }
}
