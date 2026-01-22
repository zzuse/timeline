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
        try tokenStore.saveTokens(accessToken: "jwt-token", refreshToken: "refresh-token")
        let client = NotesyncClient(
            configuration: AppConfiguration(
                baseURL: URL(string: "https://example.com")!,
                auth: .init(
                    loginURL: URL(string: "https://example.com/login")!,
                    apiKey: "unused",
                callbackScheme: "zzuse.timeline",
                callbackHost: "auth",
                callbackPath: "/callback"
            ),
            notesync: .init(apiKey: "key", maxRequestBytes: 10 * 1024 * 1024)
        ),
            tokenStore: tokenStore,
            session: NotesyncSessionStub()
        )
        let manager = NotesyncManager(queue: queue, client: client)

        try await manager.performSync()
        #expect((try queue.pending()).isEmpty)
    }

    @Test func syncRemovesSentBatchOnFailure() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let note1 = Note(text: "Hello", imagePaths: [], tags: [])
        let note2 = Note(text: "World", imagePaths: [], tags: [])
        try queue.enqueueCreate(note: note1, imagePaths: [], audioPaths: [], tags: ["work"])
        try queue.enqueueCreate(note: note2, imagePaths: [], audioPaths: [], tags: ["work"])

        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveTokens(accessToken: "jwt-token", refreshToken: "refresh-token")
        let client = NotesyncClient(
            configuration: AppConfiguration(
                baseURL: URL(string: "https://example.com")!,
                auth: .init(
                    loginURL: URL(string: "https://example.com/login")!,
                    apiKey: "unused",
                    callbackScheme: "zzuse.timeline",
                callbackHost: "auth",
                callbackPath: "/callback"
            ),
            notesync: .init(apiKey: "key", maxRequestBytes: 100_000)
        ),
        tokenStore: tokenStore,
        session: NotesyncFailingSession()
    )
        let manager = NotesyncManager(
            queue: queue,
            client: client,
            maxRequestBytes: 100_000,
            batcher: NotesyncBatcherStub()
        )

        do {
            try await manager.performSync()
            #expect(Bool(false))
        } catch {
            // Expected failure after first batch.
        }

        #expect((try queue.pending()).count == 1)
    }
}

final class NotesyncSessionStub: NotesyncSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}

final class NotesyncFailingSession: NotesyncSession {
    private var callCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        if callCount > 1 {
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}

struct NotesyncBatcherStub: NotesyncBatching {
    func split(ops: [SyncOperationPayload]) throws -> [[SyncOperationPayload]] {
        guard ops.count > 1 else { return [ops] }
        return [[ops[0]], Array(ops.dropFirst())]
    }
}
