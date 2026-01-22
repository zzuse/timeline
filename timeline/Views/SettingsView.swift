import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSessionManager
    @EnvironmentObject private var syncState: NotesyncUIState

    let onFullResync: () -> Void
    let onDismiss: () -> Void

    @State private var isConfirmingResync = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if authSession.isSignedIn {
                        Button("Logout", role: .destructive) {
                            authSession.signOut()
                            onDismiss()
                        }
                    } else {
                        Text("Sign in to manage account.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sync") {
                    if authSession.isSignedIn {
                        Button("Full Resync") {
                            isConfirmingResync = true
                        }
                    } else {
                        Text("Sign in to use sync tools.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Status") {
                    LabeledContent("Last Sync", value: syncState.lastSyncStatusText)
                    LabeledContent("Last Error", value: syncState.lastErrorStatusText)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .alert("Full Resync", isPresented: $isConfirmingResync) {
                Button("Cancel", role: .cancel) {}
                Button("Resync") {
                    onFullResync()
                }
            } message: {
                Text("This will queue all local notes for upload.")
            }
        }
    }
}

#Preview {
    SettingsView(onFullResync: {}, onDismiss: {})
}
