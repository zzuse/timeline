import Foundation
import Testing
@testable import timeline

struct NotesyncClientTests {
    @Test func clientSendsAuthHeaders() async throws {
        let config = NotesyncConfiguration(baseURL: URL(string: "https://example.com")!, apiKey: "key")
        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveToken("jwt-token")
        let session = URLSessionMock()
        let client = NotesyncClient(configuration: config, tokenStore: tokenStore, session: session)

        try await client.send(payload: SyncRequest(ops: []))

        #expect(session.lastRequest?.value(forHTTPHeaderField: "X-API-Key") == "key")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
    }
}

final class URLSessionMock: URLSession {
    var lastRequest: URLRequest?

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}
