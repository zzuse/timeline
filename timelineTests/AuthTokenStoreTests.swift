import Testing
@testable import timeline

struct AuthTokenStoreTests {
    @Test func tokenStoreRoundTrip() async throws {
        let store = InMemoryAuthTokenStore()
        #expect(try store.loadToken() == nil)

        try store.saveToken("jwt-token")
        #expect(try store.loadToken() == "jwt-token")

        try store.clearToken()
        #expect(try store.loadToken() == nil)
    }
}
