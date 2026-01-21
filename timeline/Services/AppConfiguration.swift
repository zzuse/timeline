import Foundation

struct AppConfiguration {
    struct Auth {
        let loginURL: URL
        let apiKey: String
        let callbackScheme: String
        let callbackHost: String
        let callbackPath: String
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
            loginURL: URL(string: "https://zzuse.duckdns.org/auth/oauth_start?client=ios")!,
            apiKey: "replace-me",
            callbackScheme: "zzuse.timeline",
            callbackHost: "auth",
            callbackPath: "/callback"
        ),
        notesync: Notesync(apiKey: "replace-me")
    )
}
