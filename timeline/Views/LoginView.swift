import SwiftUI

struct LoginView: View {
    let loginURL = AppConfiguration.default.auth.loginURL

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign in to Sync")
                .font(.title2)
            Link("Continue in Browser", destination: loginURL)
        }
        .padding()
    }
}

#Preview {
    LoginView()
}
