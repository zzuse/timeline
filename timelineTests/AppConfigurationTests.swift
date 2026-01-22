import Foundation
import Testing
@testable import timeline

struct AppConfigurationTests {
    @Test func configurationHasDefaults() async throws {
        let config = AppConfiguration.default
        #expect(config.baseURL.absoluteString == "https://zzuse.duckdns.org")
        #expect(config.auth.loginURL.absoluteString == "https://zzuse.duckdns.org/auth/oauth_start?client=ios")
        #expect(config.auth.apiKey == "replace-me")
        #expect(config.auth.callbackScheme == "zzuse.timeline")
        #expect(config.auth.callbackHost == "auth")
        #expect(config.auth.callbackPath == "/callback")
        #expect(config.notesync.apiKey == "replace-me")
        #expect(config.notesync.maxRequestBytes == 10 * 1024 * 1024)
    }
}
