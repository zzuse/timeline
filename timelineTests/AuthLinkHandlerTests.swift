import Foundation
import Testing
@testable import timeline

struct AuthLinkHandlerTests {
    @Test func authCallbackParsesCode() async throws {
        let handler = AuthLinkHandler()
        let url = URL(string: "https://zzuse.duckdns.org/auth/callback?code=abc123")!
        let result = handler.parseCallback(url: url)
        #expect(result?.code == "abc123")
    }
}
