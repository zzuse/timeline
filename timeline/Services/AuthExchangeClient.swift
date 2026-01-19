import Foundation

struct AuthExchangeRequest: Codable {
    let code: String
}

struct AuthExchangeResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
}

protocol AuthExchangeClientType {
    func exchange(code: String) async throws -> AuthExchangeResponse
}

final class AuthExchangeClient: AuthExchangeClientType {
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func exchange(code: String) async throws -> AuthExchangeResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/auth/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try encoder.encode(AuthExchangeRequest(code: code))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(AuthExchangeResponse.self, from: data)
    }
}
