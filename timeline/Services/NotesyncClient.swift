import Foundation

protocol NotesyncSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NotesyncSession {}

struct NotesyncHTTPError: LocalizedError {
    let statusCode: Int
    let body: String?

    var errorDescription: String? {
        if let body, !body.isEmpty {
            return "Notesync failed (\(statusCode)): \(body)"
        }
        return "Notesync failed with status \(statusCode)."
    }
}

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
        let token = try tokenStore.loadAccessToken()
        guard let token else { throw URLError(.userAuthenticationRequired) }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body = try encoder.encode(payload)
        request.httpBody = body
        logPayloadStats(payload, bodySize: body.count)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let http = response as? HTTPURLResponse {
                let body = String(data: data, encoding: .utf8)
                throw NotesyncHTTPError(statusCode: http.statusCode, body: body)
            }
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(SyncResponse.self, from: data)
    }

    private func logPayloadStats(_ payload: SyncRequest, bodySize: Int) {
        let mediaPayloads = payload.ops.flatMap(\.media)
        let mediaCount = mediaPayloads.count
        let mediaBase64Bytes = mediaPayloads.reduce(0) { $0 + $1.dataBase64.utf8.count }
        print("Notesync payload bytes=\(bodySize), ops=\(payload.ops.count), media=\(mediaCount), mediaBase64Bytes=\(mediaBase64Bytes)")
        for media in mediaPayloads {
            let size = media.dataBase64.utf8.count
            print("Notesync media id=\(media.id) filename=\(media.filename) base64Bytes=\(size)")
        }
    }
}
