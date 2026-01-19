import Foundation
import Testing
@testable import timeline

struct AuthLinkHandlerTests {
    @Test func authCallbackParsesCode() async throws {
        let handler = AuthLinkHandler(baseURL: AppConfiguration.default.baseURL)
        let url = URL(string: "https://zzuse.duckdns.org/auth/callback?code=abc123")!
        let result = handler.parseCallback(url: url)
        #expect(result?.code == "abc123")
    }

    @Test func authCallbackRejectsUnexpectedHost() async throws {
        let handler = AuthLinkHandler(baseURL: URL(string: "https://example.com")!)
        let url = URL(string: "https://zzuse.duckdns.org/auth/callback?code=abc123")!
        let result = handler.parseCallback(url: url)
        #expect(result == nil)
    }
}
