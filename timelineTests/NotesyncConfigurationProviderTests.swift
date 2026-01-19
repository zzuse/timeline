import Testing
@testable import timeline

struct NotesyncConfigurationProviderTests {
    @Test func providerUsesAppDefaults() async throws {
        let config = NotesyncConfigurationProvider.defaultConfiguration
        #expect(config.baseURL == AppConfiguration.default.baseURL)
        #expect(config.notesync.apiKey == AppConfiguration.default.notesync.apiKey)
    }
}
