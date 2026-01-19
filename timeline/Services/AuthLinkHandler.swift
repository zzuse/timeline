import Foundation

struct AuthCallbackResult {
    let code: String
    let state: String?
}

struct AuthLinkHandler {
    private let allowedScheme: String
    private let allowedHost: String
    private let allowedPath: String

    init(configuration: AppConfiguration.Auth) {
        self.allowedScheme = configuration.callbackScheme
        self.allowedHost = configuration.callbackHost
        self.allowedPath = configuration.callbackPath
    }

    func parseCallback(url: URL) -> AuthCallbackResult? {
        guard url.scheme == allowedScheme,
              url.host == allowedHost,
              url.path == allowedPath,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        return AuthCallbackResult(code: code, state: state)
    }
}
