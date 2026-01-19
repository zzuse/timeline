import Foundation
import Testing
@testable import timeline

struct AppConfigurationTests {
    @Test func configurationHasDefaults() async throws {
        let config = AppConfiguration.default
        #expect(config.baseURL.absoluteString == "https://zzuse.duckdns.org")
        #expect(config.auth.loginURL.absoluteString == "https://zzuse.duckdns.org/login")
        #expect(config.auth.apiKey == "replace-me")
        #expect(config.notesync.apiKey == "replace-me")
    }
}
