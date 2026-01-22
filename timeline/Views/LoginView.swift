import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authSession: AuthSessionManager
    let loginURL = AppConfiguration.default.auth.loginURL

    var body: some View {
        VStack(spacing: 16) {
            if authSession.didSignInSuccessfully {
                Text("Signed in successfully")
                    .font(.title2)
                Text("Returning to Timeline…")
                    .foregroundStyle(.secondary)
            } else {
                Text("Sign in to Sync")
                    .font(.title2)
                Link("Continue in Browser", destination: loginURL)
            }
        }
        .padding()
    }
}

#Preview {
    LoginView()
}
