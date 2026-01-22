# Settings + Full Resync + Restore Latest 10 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Settings sheet with Logout + Full Resync + sync status (Logout only in Settings), plus an empty-state “Restore latest 10” action that pulls recent notes from the server into SwiftData.

**Architecture:** Introduce a SettingsView presented from TimelineView, wire Logout and Full Resync actions to new repository/auth APIs (no toolbar Logout), and add a restore flow that fetches the latest notes from a new endpoint and upserts them into local storage. The restore action is only visible when the local list is empty and user is signed in. Use TDD for new behaviors.

**Tech Stack:** SwiftUI, SwiftData, Foundation, URLSession, Testing (swift-testing), CryptoKit (existing checksum).

---

## Implementation Checklist

- Add Settings sheet entry point (gear icon) and `SettingsView` sheet wiring in `TimelineView`.
- Add Logout action in Settings that clears tokens and dismisses sheet.
- Add Full Resync action with confirmation alert and enqueue-all flow.
- Add Notesync status display (“Last Sync”, “Last Error”) with fallback text.
- Add empty-state “Restore latest 10” CTA gated by sign-in.
- Add restore API client + response types (latest notes + media).
- Add restore upsert into SwiftData, media saving, and partial-failure handling.
- Add login success UI (success message + auto-dismiss) and `didSignInSuccessfully` state.
- Add tests for settings visibility, status fallbacks, restore gating, and login success state.

## Test Case Design

- Settings sheet appears from gear icon and includes Account/Sync/Status sections.
- Logout visible only when signed in; signing out clears tokens and dismisses sheet.
- Full Resync visible only when signed in; confirmation alert appears; enqueue count equals notes count.
- Status fields show “Never/None” when nil; formatted dates when set.
- Empty-state shows “Restore latest 10” only when signed in and notes list empty.
- Restore uses correct endpoint + headers; upserts notes by id; skips duplicate media by checksum.
- Restore handles partial media failures without blocking note insertion.
- Login success flag sets on code exchange; login sheet shows success message then dismisses.

---

### Task 1: Add sign-out support in AuthSessionManager

**Files:**
- Modify: `timeline/Services/AuthSessionManager.swift`
- Modify: `timeline/Services/AuthTokenStore.swift`
- Modify: `timelineTests/AuthSessionManagerTests.swift`
- Modify: `timelineTests/AuthTokenStoreTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/AuthSessionManagerTests.swift
@Test func signOutClearsTokenAndState() async throws {
    let store = InMemoryAuthTokenStore()
    try store.saveToken("jwt-token")
    let manager = AuthSessionManager(tokenStore: store, exchangeClient: AuthExchangeStub())
    #expect(manager.isSignedIn == true)

    manager.signOut()

    #expect(manager.isSignedIn == false)
    #expect(try store.loadToken() == nil)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/AuthSessionManagerTests.signOutClearsTokenAndState`  
Expected: FAIL with missing `signOut` or token not cleared.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/AuthSessionManager.swift
func signOut() {
    try? tokenStore.clearToken()
    isSignedIn = false
}
```

```swift
// timeline/Services/AuthTokenStore.swift
protocol AuthTokenStore {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func clearToken() throws
}
```

Add `clearToken()` to Keychain store and InMemory store if missing.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/AuthSessionManagerTests.signOutClearsTokenAndState`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/AuthSessionManager.swift timeline/Services/AuthTokenStore.swift timelineTests/AuthSessionManagerTests.swift timelineTests/AuthTokenStoreTests.swift
git commit -m "feat: add sign-out token clearing"
```

---

### Task 2: Add Settings sheet UI (Logout + Full Resync + Status)

**Files:**
- Create: `timeline/Views/SettingsView.swift`
- Modify: `timeline/Views/TimelineView.swift`
- Modify: `timelineTests/SyncUIStateTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/SyncUIStateTests.swift
@Test func syncStateStatusStringsFallback() async throws {
    let state = NotesyncUIState()
    #expect(state.lastSyncStatusText == "Never")
    #expect(state.lastErrorStatusText == "None")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncUIStateTests.syncStateStatusStringsFallback`  
Expected: FAIL with missing status text helpers.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesyncUIState.swift
var lastSyncStatusText: String {
    if let lastSyncAt { return lastSyncAt.formatted(date: .abbreviated, time: .shortened) }
    return "Never"
}

var lastErrorStatusText: String {
    lastError?.isEmpty == false ? lastError! : "None"
}
```

Create SettingsView:

```swift
// timeline/Views/SettingsView.swift
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
                    Button("Done") { onDismiss() }
                }
            }
            .alert("Full Resync", isPresented: $isConfirmingResync) {
                Button("Cancel", role: .cancel) {}
                Button("Resync") {
                    onFullResync()
                    onDismiss()
                }
            } message: {
                Text("This will queue all local notes for upload.")
            }
        }
    }
}
```

Wire the sheet in TimelineView with a gear button and `SettingsView`.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncUIStateTests.syncStateStatusStringsFallback`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Views/SettingsView.swift timeline/Views/TimelineView.swift timeline/Services/NotesyncUIState.swift timelineTests/SyncUIStateTests.swift
git commit -m "feat: add settings sheet with logout, resync, status"
```

---

### Task 3: Add Full Resync enqueue in NotesRepository

**Files:**
- Modify: `timeline/Services/NotesRepository.swift`
- Modify: `timeline/Services/SyncQueue.swift`
- Modify: `timelineTests/timelineTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/timelineTests.swift
@Test func repositoryFullResyncEnqueuesAllNotes() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
    let context = ModelContext(container)
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = try SyncQueue(baseURL: temp)
    let repo = NotesRepository(context: context, imageStore: ImageStore(), audioStore: AudioStore(), syncQueue: queue)

    let a = Note(text: "A", imagePaths: [], tags: [])
    let b = Note(text: "B", imagePaths: [], tags: [])
    context.insert(a)
    context.insert(b)
    try context.save()

    try repo.enqueueFullResync()

    let items = try queue.pending()
    #expect(items.count == 2)
    #expect(items.allSatisfy { $0.opType == .update })
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.repositoryFullResyncEnqueuesAllNotes`  
Expected: FAIL with missing `enqueueFullResync`.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesRepository.swift
func enqueueFullResync() throws {
    let descriptor = FetchDescriptor<Note>()
    let notes = try context.fetch(descriptor)
    for note in notes {
        try syncQueue.enqueueUpdate(
            note: note,
            imagePaths: note.imagePaths,
            audioPaths: note.audioPaths,
            tags: note.tags.map(\.name)
        )
    }
}
```

Ensure SyncQueue has a public `enqueueUpdate` that accepts full media; no changes needed if already present.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.repositoryFullResyncEnqueuesAllNotes`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/NotesRepository.swift timelineTests/timelineTests.swift
git commit -m "feat: enqueue full resync for all notes"
```

---

### Task 4: Add Restore Latest 10 API client and payloads

**Files:**
- Modify: `timeline/Services/NotesyncAPI.swift`
- Modify: `timeline/Services/NotesyncClient.swift`
- Modify: `timelineTests/NotesyncClientTests.swift`

**Step 0: Confirm backend endpoint**

Assume `GET /api/notes?limit=10` returns:

```json
{
  "notes": [SyncNotePayload...],
  "media": [SyncMediaPayload...]
}
```

If the backend uses a different endpoint, update paths and response shape here.

**Step 1: Write the failing test**

```swift
// timelineTests/NotesyncClientTests.swift
@Test func clientFetchesLatestNotes() async throws {
    let config = AppConfiguration(
        baseURL: URL(string: "https://example.com")!,
        auth: .init(loginURL: URL(string: "https://example.com/login")!, apiKey: "unused", callbackScheme: "app", callbackHost: "auth", callbackPath: "/callback"),
        notesync: .init(apiKey: "key")
    )
    let tokenStore = InMemoryAuthTokenStore()
    try tokenStore.saveToken("jwt-token")
    let session = NotesyncSessionMock()
    let client = NotesyncClient(configuration: config, tokenStore: tokenStore, session: session)

    _ = try await client.fetchLatestNotes(limit: 10)

    #expect(session.lastRequest?.url?.absoluteString == "https://example.com/api/notes?limit=10")
    #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncClientTests.clientFetchesLatestNotes`  
Expected: FAIL with missing `fetchLatestNotes`.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesyncAPI.swift
struct NotesyncRestoreResponse: Codable {
    let notes: [SyncNotePayload]
    let media: [SyncMediaPayload]
}
```

```swift
// timeline/Services/NotesyncClient.swift
func fetchLatestNotes(limit: Int) async throws -> NotesyncRestoreResponse {
    var components = URLComponents(url: configuration.baseURL.appendingPathComponent("/api/notes"), resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
    guard let url = components?.url else { throw URLError(.badURL) }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue(configuration.notesync.apiKey, forHTTPHeaderField: "X-API-Key")
    let token = try tokenStore.loadToken()
    guard let token else { throw URLError(.userAuthenticationRequired) }
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw URLError(.badServerResponse)
    }
    return try decoder.decode(NotesyncRestoreResponse.self, from: data)
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncClientTests.clientFetchesLatestNotes`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/NotesyncAPI.swift timeline/Services/NotesyncClient.swift timelineTests/NotesyncClientTests.swift
git commit -m "feat: add restore latest notes client"
```

---

### Task 5: Implement restore upsert into SwiftData

**Files:**
- Modify: `timeline/Services/NotesRepository.swift`
- Modify: `timeline/Services/NotesyncManager.swift`
- Modify: `timelineTests/timelineTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/timelineTests.swift
@Test func repositoryUpsertsNotesById() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
    let context = ModelContext(container)
    let repo = NotesRepository(context: context, imageStore: ImageStore(), audioStore: AudioStore())

    let note = Note(text: "Old", imagePaths: [], tags: [])
    note.id = "note-1"
    context.insert(note)
    try context.save()

    try repo.upsertNote(
        id: "note-1",
        text: "New",
        isPinned: false,
        tags: [],
        createdAt: note.createdAt,
        updatedAt: Date(),
        deletedAt: nil,
        imagePaths: [],
        audioPaths: []
    )

    let stored = try context.fetch(FetchDescriptor<Note>())
    #expect(stored.count == 1)
    #expect(stored.first?.text == "New")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.repositoryUpsertsNotesById`  
Expected: FAIL with missing `upsertNote`.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesRepository.swift
func upsertNote(
    id: String,
    text: String,
    isPinned: Bool,
    tags: [String],
    createdAt: Date,
    updatedAt: Date,
    deletedAt: Date?,
    imagePaths: [String],
    audioPaths: [String]
) throws {
    let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
    let existing = try context.fetch(descriptor).first
    let note = existing ?? Note(text: text, imagePaths: imagePaths, audioPaths: audioPaths, tags: Tag.normalized(from: tags))
    note.id = id
    note.text = text
    note.isPinned = isPinned
    note.tags = Tag.normalized(from: tags)
    note.createdAt = createdAt
    note.updatedAt = updatedAt
    note.deletedAt = deletedAt
    note.imagePaths = imagePaths
    note.audioPaths = audioPaths
    if existing == nil {
        context.insert(note)
    }
    try context.save()
}
```

Add a restore method in NotesyncManager:

```swift
func restoreLatestNotes(limit: Int, repository: NotesRepository) async throws {
    let response = try await client.fetchLatestNotes(limit: limit)
    for note in response.notes {
        let mediaForNote = response.media.filter { $0.noteId == note.id }
        let (imagePaths, audioPaths) = try repository.saveRestoreMedia(noteId: note.id, media: mediaForNote)
        try repository.upsertNote(
            id: note.id,
            text: note.text,
            isPinned: note.isPinned,
            tags: note.tags,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            deletedAt: note.deletedAt,
            imagePaths: imagePaths,
            audioPaths: audioPaths
        )
    }
}
```

Add `saveRestoreMedia` in NotesRepository to write base64 media to ImageStore/AudioStore and return paths.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.repositoryUpsertsNotesById`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/NotesRepository.swift timeline/Services/NotesyncManager.swift timelineTests/timelineTests.swift
git commit -m "feat: upsert notes and restore latest notes"
```

---

### Task 6: Wire Restore action in empty-state

**Files:**
- Modify: `timeline/Views/TimelineView.swift`
- Modify: `timeline/Services/NotesyncUIState.swift`
- Modify: `timelineTests/SyncUIStateTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/SyncUIStateTests.swift
@Test func restoreIsDisabledWhenSignedOut() async throws {
    let state = NotesyncUIState()
    #expect(state.isRestoreDisabled(isSignedIn: false) == true)
    #expect(state.isRestoreDisabled(isSignedIn: true) == false)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncUIStateTests.restoreIsDisabledWhenSignedOut`  
Expected: FAIL with missing `isRestoreDisabled`.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesyncUIState.swift
func isRestoreDisabled(isSignedIn: Bool) -> Bool {
    isSyncing || !isSignedIn
}
```

In TimelineView empty-state, add a Restore button when `notes.isEmpty`:

```swift
Button {
    Task { await restoreLatest() }
} label: {
    Label("Restore latest 10", systemImage: "arrow.clockwise")
}
.disabled(syncState.isRestoreDisabled(isSignedIn: authSession.isSignedIn))
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncUIStateTests.restoreIsDisabledWhenSignedOut`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Views/TimelineView.swift timeline/Services/NotesyncUIState.swift timelineTests/SyncUIStateTests.swift
git commit -m "feat: add empty-state restore action"
```

---

## Verification

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0'`  
Expected: All tests pass.
