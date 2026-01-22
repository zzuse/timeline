import Testing
@testable import timeline

struct AuthTokenStoreTests {
    @Test func tokenStoreRoundTrip() async throws {
        let store = InMemoryAuthTokenStore()
        #expect(try store.loadAccessToken() == nil)
        #expect(try store.loadRefreshToken() == nil)

        try store.saveTokens(accessToken: "jwt-token", refreshToken: "refresh-token")
        #expect(try store.loadAccessToken() == "jwt-token")
        #expect(try store.loadRefreshToken() == "refresh-token")

        try store.clearTokens()
        #expect(try store.loadAccessToken() == nil)
        #expect(try store.loadRefreshToken() == nil)
    }
}
