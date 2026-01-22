import Foundation
import Testing
@testable import timeline

final class AuthExchangeStub: AuthExchangeClientType {
    func exchange(code: String) async throws -> AuthExchangeResponse {
        AuthExchangeResponse(accessToken: "jwt", refreshToken: "refresh", tokenType: "Bearer", expiresIn: 3600)
    }
}

struct AuthSessionManagerTests {
    @Test func savesTokenAfterExchange() async throws {
        let store = InMemoryAuthTokenStore()
        let manager = AuthSessionManager(tokenStore: store, exchangeClient: AuthExchangeStub())
        let url = URL(string: "zzuse.timeline://auth/callback?code=abc123")!
        await manager.handleCallback(url: url)
        #expect(try store.loadAccessToken() == "jwt")
        #expect(try store.loadRefreshToken() == "refresh")
    }

    @Test func signOutClearsTokenAndState() async throws {
        let store = InMemoryAuthTokenStore()
        try store.saveTokens(accessToken: "jwt-token", refreshToken: "refresh-token")
        let manager = AuthSessionManager(tokenStore: store, exchangeClient: AuthExchangeStub())
        #expect(manager.isSignedIn == true)

        manager.signOut()

        #expect(manager.isSignedIn == false)
        #expect(try store.loadAccessToken() == nil)
        #expect(try store.loadRefreshToken() == nil)
    }

    @Test func signInSetsSuccessFlag() async throws {
        let store = InMemoryAuthTokenStore()
        let manager = AuthSessionManager(tokenStore: store, exchangeClient: AuthExchangeStub())
        let url = URL(string: "zzuse.timeline://auth/callback?code=abc123")!

        await manager.handleCallback(url: url)

        #expect(manager.didSignInSuccessfully == true)
    }
}
