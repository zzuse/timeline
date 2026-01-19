import Foundation

struct AppConfiguration {
    struct Auth {
        let loginURL: URL
        let apiKey: String
    }

    struct Notesync {
        let apiKey: String
    }

    let baseURL: URL
    let auth: Auth
    let notesync: Notesync

    static let `default` = AppConfiguration(
        baseURL: URL(string: "https://zzuse.duckdns.org")!,
        auth: Auth(
            loginURL: URL(string: "https://zzuse.duckdns.org/login")!,
            apiKey: "replace-me"
        ),
        notesync: Notesync(apiKey: "replace-me")
    )
}
