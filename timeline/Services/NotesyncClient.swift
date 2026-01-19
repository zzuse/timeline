import Foundation

protocol NotesyncSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NotesyncSession {}

final class NotesyncClient {
    private let configuration: AppConfiguration
    private let tokenStore: AuthTokenStore
    private let session: NotesyncSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: AppConfiguration, tokenStore: AuthTokenStore, session: NotesyncSession = URLSession.shared) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func send(payload: SyncRequest) async throws -> SyncResponse {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("/api/notesync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.notesync.apiKey, forHTTPHeaderField: "X-API-Key")
        let token = try tokenStore.loadToken()
        guard let token else { throw URLError(.userAuthenticationRequired) }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(SyncResponse.self, from: data)
    }
}
