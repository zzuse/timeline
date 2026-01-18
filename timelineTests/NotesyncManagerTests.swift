import Foundation
import Testing
@testable import timeline

struct NotesyncManagerTests {
    @Test func syncClearsQueueOnSuccess() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let note = Note(text: "Hello", imagePaths: [], tags: [])
        try queue.enqueueCreate(note: note, imagePaths: [], audioPaths: [], tags: ["work"])

        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveToken("jwt-token")
        let client = NotesyncClient(
            configuration: .init(baseURL: URL(string: "https://example.com")!, apiKey: "key"),
            tokenStore: tokenStore,
            session: NotesyncSessionStub()
        )
        let manager = NotesyncManager(queue: queue, client: client)

        try await manager.performSync()
        #expect((try queue.pending()).isEmpty)
    }
}

final class NotesyncSessionStub: NotesyncSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}
