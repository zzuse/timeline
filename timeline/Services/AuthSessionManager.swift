import Foundation

final class AuthSessionManager: ObservableObject {
    @Published var isSignedIn = false
    private let tokenStore: AuthTokenStore
    private let handler: AuthLinkHandler
    private let exchangeClient: AuthExchangeClientType

    init(
        tokenStore: AuthTokenStore = KeychainAuthTokenStore(),
        exchangeClient: AuthExchangeClientType = AuthExchangeClient(
            baseURL: AppConfiguration.default.baseURL,
            apiKey: AppConfiguration.default.auth.apiKey
        )
    ) {
        self.tokenStore = tokenStore
        self.exchangeClient = exchangeClient
        self.handler = AuthLinkHandler(baseURL: AppConfiguration.default.baseURL)
        self.isSignedIn = (try? tokenStore.loadToken()) != nil
    }

    func handleCallback(url: URL) async {
        guard let result = handler.parseCallback(url: url) else { return }
        do {
            let response = try await exchangeClient.exchange(code: result.code)
            try tokenStore.saveToken(response.accessToken)
            isSignedIn = true
        } catch {
            isSignedIn = false
        }
    }
}
