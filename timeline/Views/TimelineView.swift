import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    @EnvironmentObject private var syncState: NotesyncUIState
    @EnvironmentObject private var authSession: AuthSessionManager

    @State private var isShowingCompose = false
    @State private var isShowingFilters = false
    @State private var isShowingSettings = false
    @State private var editingNote: Note?
    @State private var errorMessage: String?
    @State private var isShowingError = false
    @State private var isShowingSyncError = false
    @State private var isShowingLogin = false
    @State private var searchText = ""
    @State private var selectedTags: [String] = []

    private let imageStore = ImageStore()
    private let audioStore = AudioStore()
    private let syncQueue = try! SyncQueue()
    private let tokenStore = KeychainAuthTokenStore()

    private var syncManager: NotesyncManager {
        let config = NotesyncConfigurationProvider.defaultConfiguration
        let client = NotesyncClient(configuration: config, tokenStore: tokenStore)
        return NotesyncManager(queue: syncQueue, client: client)
    }

    private var sortedNotes: [Note] {
        let filtered = TimelineFilter.search(text: searchText, tags: selectedTags).apply(to: notes)
        return NoteSorter.sort(filtered)
    }

    private var pinnedNotes: [Note] {
        sortedNotes.filter { $0.isPinned }
    }

    private var regularNotes: [Note] {
        sortedNotes.filter { !$0.isPinned }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Notes Yet",
                        systemImage: "square.and.pencil",
                        description: Text("Create your first note to start the timeline.")
                    )
                    if authSession.isSignedIn {
                        Button {
                            Task {
                                await restoreLatest()
                            }
                        } label: {
                            Label("Restore latest 10", systemImage: "arrow.clockwise")
                        }
                        .disabled(syncState.isRestoreDisabled(isSignedIn: authSession.isSignedIn))
                    } else {
                        Text("Sign in to restore.")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                List {
                    if !pinnedNotes.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedNotes, id: \.persistentModelID) { note in
                                NavigationLink {
                                    DetailView(note: note)
                                } label: {
                                    NoteRow(note: note)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        editingNote = note
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button {
                                        togglePin(note)
                                    } label: {
                                        Label(note.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                                    }
                                    .tint(.orange)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    Section("All") {
                        ForEach(regularNotes, id: \.persistentModelID) { note in
                            NavigationLink {
                                DetailView(note: note)
                            } label: {
                                NoteRow(note: note)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingNote = note
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button {
                                    togglePin(note)
                                } label: {
                                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: "pin")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Timeline")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCompose = true
                } label: {
                    Label("New Note", systemImage: "square.and.pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !authSession.isSignedIn {
                    Button {
                        isShowingLogin = true
                    } label: {
                        Label("Sign In", systemImage: "person.crop.circle")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await syncNow()
                    }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(syncState.isSyncDisabled(isSignedIn: authSession.isSignedIn))
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingFilters = true
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $isShowingCompose) {
            NavigationStack {
                ComposeView()
            }
        }
        .sheet(isPresented: $isShowingLogin) {
            NavigationStack {
                LoginView()
            }
        }
        .sheet(isPresented: $isShowingFilters) {
            SearchFilterView(searchText: $searchText, selectedTags: $selectedTags)
        }
        .sheet(item: $editingNote) { note in
            NavigationStack {
                EditView(note: note)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                onFullResync: {
                    Task {
                        let didEnqueue = await fullResync()
                        if didEnqueue {
                            isShowingSettings = false
                        }
                    }
                },
                onDismiss: {
                    isShowingSettings = false
                }
            )
        }
        .alert("Something went wrong", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .alert("Sync Failed", isPresented: $isShowingSyncError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncState.lastError ?? "Unable to sync. Please try again.")
        }
        .onChange(of: authSession.didSignInSuccessfully) { _, didSignInSuccessfully in
            guard didSignInSuccessfully else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                isShowingLogin = false
                authSession.clearSignInSuccess()
            }
        }
    }

    private var repository: NotesRepository {
        NotesRepository(context: modelContext, imageStore: imageStore, audioStore: audioStore, syncQueue: syncQueue)
    }

    private func togglePin(_ note: Note) {
        note.isPinned.toggle()
        note.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            showError("Unable to update pin status.")
        }
    }

    private func delete(_ note: Note) {
        do {
            try repository.delete(note: note)
        } catch {
            showError("Unable to delete this note.")
        }
    }

    private func syncNow() async {
        syncState.isSyncing = true
        do {
            try await syncManager.performSync()
            syncState.lastSyncAt = Date()
        } catch {
            if let notesyncError = error as? NotesyncHTTPError,
               let body = notesyncError.body,
               body.contains("token_expired") {
                syncState.lastError = "Session expired. Please sign in again."
                isShowingLogin = true
            } else {
                syncState.lastError = error.localizedDescription
            }
            isShowingSyncError = true
        }
        syncState.isSyncing = false
    }

    private func fullResync() async -> Bool {
        do {
            try repository.enqueueFullResync()
            await syncNow()
            return true
        } catch {
            showError("Resync failed to enqueue.")
            return false
        }
    }

    private func restoreLatest() async {
        do {
            try await syncManager.restoreLatestNotes(limit: 10, repository: repository)
        } catch {
            if let notesyncError = error as? NotesyncHTTPError,
               let body = notesyncError.body,
               body.contains("token_expired") {
                syncState.lastError = "Session expired. Please sign in again."
                isShowingLogin = true
            } else {
                syncState.lastError = error.localizedDescription
            }
            isShowingSyncError = true
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}

#Preview {
    TimelineView()
}
