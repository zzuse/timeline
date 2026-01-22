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
            notesync: .init(apiKey: "key", maxRequestBytes: 10 * 1024 * 1024)
        )
        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveTokens(accessToken: "jwt-token", refreshToken: "refresh-token")
        let session = NotesyncSessionMock()
        let client = NotesyncClient(configuration: config, tokenStore: tokenStore, session: session)

        try await client.send(payload: SyncRequest(ops: []))

        #expect(session.lastRequest?.value(forHTTPHeaderField: "X-API-Key") == "key")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
    }

    @Test func clientRefreshesAndRetriesOnTokenExpired() async throws {
        let config = AppConfiguration(
            baseURL: URL(string: "https://example.com")!,
            auth: .init(
                loginURL: URL(string: "https://example.com/login")!,
                apiKey: "auth-key",
                callbackScheme: "zzuse.timeline",
                callbackHost: "auth",
                callbackPath: "/callback"
            ),
            notesync: .init(apiKey: "key", maxRequestBytes: 10 * 1024 * 1024)
        )
        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveTokens(accessToken: "old-access", refreshToken: "refresh-token")
        let session = NotesyncSessionSequence(responses: [
            .init(statusCode: 401, body: #"{"error":"token_expired"}"#),
            .init(statusCode: 200, body: #"{"results":[]}"#)
        ])
        let refreshClient = AuthRefreshStub(response: AuthExchangeResponse(
            accessToken: "new-access",
            refreshToken: "new-refresh",
            tokenType: "Bearer",
            expiresIn: 3600
        ))
        let client = NotesyncClient(
            configuration: config,
            tokenStore: tokenStore,
            session: session,
            refreshClient: refreshClient
        )

        try await client.send(payload: SyncRequest(ops: []))

        #expect(refreshClient.lastRefreshToken == "refresh-token")
        #expect(session.requests.count == 2)
        #expect(session.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new-access")
        #expect(try tokenStore.loadAccessToken() == "new-access")
        #expect(try tokenStore.loadRefreshToken() == "new-refresh")
    }

    @Test func clientFetchesLatestNotes() async throws {
        let config = AppConfiguration(
            baseURL: URL(string: "https://example.com")!,
            auth: .init(
                loginURL: URL(string: "https://example.com/login")!,
                apiKey: "unused",
                callbackScheme: "zzuse.timeline",
                callbackHost: "auth",
                callbackPath: "/callback"
            ),
            notesync: .init(apiKey: "key", maxRequestBytes: 10 * 1024 * 1024)
        )
        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveTokens(accessToken: "jwt-token", refreshToken: "refresh-token")
        let session = NotesyncSessionResponseStub(
            statusCode: 200,
            body: #"{"notes":[],"media":[]}"#
        )
        let client = NotesyncClient(configuration: config, tokenStore: tokenStore, session: session)

        let response = try await client.fetchLatestNotes(limit: 10)

        #expect(session.lastRequest?.url?.absoluteString == "https://example.com/api/notes?limit=10")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "X-API-Key") == "key")
        #expect(response.notes.isEmpty)
        #expect(response.media.isEmpty)
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

final class NotesyncSessionSequence: NotesyncSession {
    struct StubResponse {
        let statusCode: Int
        let body: String
    }

    private(set) var requests: [URLRequest] = []
    private var responses: [StubResponse]

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = responses.isEmpty
            ? StubResponse(statusCode: 200, body: #"{"results":[]}"#)
            : responses.removeFirst()
        let http = HTTPURLResponse(url: request.url!, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        return (response.body.data(using: .utf8) ?? Data(), http)
    }
}

final class NotesyncSessionResponseStub: NotesyncSession {
    let statusCode: Int
    let body: String
    var lastRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (body.data(using: .utf8) ?? Data(), response)
    }
}

final class AuthRefreshStub: AuthRefreshClientType {
    let response: AuthExchangeResponse
    private(set) var lastRefreshToken: String?

    init(response: AuthExchangeResponse) {
        self.response = response
    }

    func refresh(baseURL: URL, apiKey: String, refreshToken: String) async throws -> AuthExchangeResponse {
        lastRefreshToken = refreshToken
        return response
    }
}
