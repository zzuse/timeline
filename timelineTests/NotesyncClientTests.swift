import Foundation
import Testing
@testable import timeline

struct NotesyncClientTests {
    @Test func clientSendsAuthHeaders() async throws {
        let config = AppConfiguration(
            baseURL: URL(string: "https://example.com")!,
            auth: .init(
                loginURL: URL(string: "https://example.com/login")!,
                apiKey: "unused",
                callbackScheme: "zzuse.timeline",
                callbackHost: "auth",
                callbackPath: "/callback"
            ),
            notesync: .init(apiKey: "key")
        )
        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveToken("jwt-token")
        let session = NotesyncSessionMock()
        let client = NotesyncClient(configuration: config, tokenStore: tokenStore, session: session)

        try await client.send(payload: SyncRequest(ops: []))

        #expect(session.lastRequest?.value(forHTTPHeaderField: "X-API-Key") == "key")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
    }
}

final class NotesyncSessionMock: NotesyncSession {
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}
