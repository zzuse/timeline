import Foundation

struct AuthCallbackResult {
    let code: String
    let state: String?
}

struct AuthLinkHandler {
    private let allowedHost: String?

    init(baseURL: URL) {
        self.allowedHost = baseURL.host
    }

    func parseCallback(url: URL) -> AuthCallbackResult? {
        guard url.host == allowedHost,
              url.path == "/auth/callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        return AuthCallbackResult(code: code, state: state)
    }
}
