import Foundation
import Testing
@testable import timeline

struct AuthLinkHandlerTests {
    @Test func authCallbackParsesCode() async throws {
        let handler = AuthLinkHandler(configuration: AppConfiguration.default.auth)
        let url = URL(string: "zzuse.timeline://auth/callback?code=abc123")!
        let result = handler.parseCallback(url: url)
        #expect(result?.code == "abc123")
    }

    @Test func authCallbackRejectsUnexpectedHost() async throws {
        let handler = AuthLinkHandler(configuration: .init(
            loginURL: URL(string: "https://example.com/login")!,
            apiKey: "key",
            callbackScheme: "zzuse.timeline",
            callbackHost: "auth",
            callbackPath: "/callback"
        ))
        let url = URL(string: "zzuse.timeline://wrong/callback?code=abc123")!
        let result = handler.parseCallback(url: url)
        #expect(result == nil)
    }
}
