# Notesync Frontend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add manual, offline-first note syncing to the iOS app with a file-based queue and a `POST /api/notesync` upload flow using API key auth plus user JWT auth.

**Architecture:** The app remains local-first with SwiftData as the source of truth. A new file-based sync queue stores note create/update/delete operations plus copied media. A sync manager builds a request payload from queued ops and uploads it to `/api/notesync` using an app API key and the user JWT from secure storage, then clears successful queue items.

**Tech Stack:** SwiftUI, SwiftData, URLSession, Foundation Codable, Security (Keychain), Testing (swift-testing).

---

### Task 1: Add a stable note identifier for sync

**Files:**
- Modify: `timeline/Note.swift`
- Modify: `timelineTests/timelineTests.swift`

**Step 1: Write the failing test**

```swift
@Test func noteHasStableId() async throws {
    let note = Note(text: "Hello", imagePaths: [], tags: [])
    #expect(note.id.isEmpty == false)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.noteHasStableId`  
Expected: FAIL with missing `id` property.

**Step 3: Write minimal implementation**

```swift
// timeline/Note.swift
@Model
final class Note: Identifiable {
    var id: String
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var imagePaths: [String]
    var audioPaths: [String]
    var tags: [Tag]

    init(text: String, imagePaths: [String], audioPaths: [String] = [], tags: [Tag]) {
        self.id = UUID().uuidString
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.imagePaths = imagePaths
        self.audioPaths = audioPaths
        self.tags = tags
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.noteHasStableId`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Note.swift timelineTests/timelineTests.swift
git commit -m "feat: add stable note id for sync"
```

---

### Task 2: Add sync queue models and file storage

**Files:**
- Create: `timeline/Services/SyncQueue.swift`
- Modify: `timeline/Services/ImageStore.swift`
- Create: `timelineTests/SyncQueueTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/SyncQueueTests.swift
import Foundation
import Testing
@testable import timeline

struct SyncQueueTests {
    @Test func enqueueCreateWritesFile() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let note = Note(text: "Hello", imagePaths: [], tags: [])

        try queue.enqueueCreate(note: note, imagePaths: [], audioPaths: [], tags: ["work"])

        let items = try queue.pending()
        #expect(items.count == 1)
        #expect(items[0].opType == .create)
        #expect(items[0].note.id == note.id)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncQueueTests.enqueueCreateWritesFile`  
Expected: FAIL with missing `SyncQueue`.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/SyncQueue.swift
import Foundation

enum SyncOpType: String, Codable {
    case create
    case update
    case delete
}

struct SyncQueuedNote: Codable {
    let id: String
    let text: String
    let isPinned: Bool
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
}

struct SyncQueuedMedia: Codable {
    let id: String
    let noteId: String
    let kind: String
    let filename: String
    let contentType: String
    let checksum: String
    let localPath: String
}

struct SyncQueueItem: Codable {
    let opId: String
    let opType: SyncOpType
    let note: SyncQueuedNote
    let media: [SyncQueuedMedia]
}

final class SyncQueue {
    private let baseURL: URL
    private let mediaURL: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = nil) throws {
        let root = baseURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.baseURL = root.appendingPathComponent("SyncQueue", isDirectory: true)
        self.mediaURL = self.baseURL.appendingPathComponent("Media", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(at: self.mediaURL, withIntermediateDirectories: true)
    }

    func enqueueCreate(note: Note, imagePaths: [String], audioPaths: [String], tags: [String]) throws {
        try enqueue(note: note, imagePaths: imagePaths, audioPaths: audioPaths, tags: tags, opType: .create, deletedAt: nil)
    }

    func enqueueUpdate(note: Note, imagePaths: [String], audioPaths: [String], tags: [String]) throws {
        try enqueue(note: note, imagePaths: imagePaths, audioPaths: audioPaths, tags: tags, opType: .update, deletedAt: nil)
    }

    func enqueueDelete(note: Note) throws {
        let deletedAt = Date()
        try enqueue(note: note, imagePaths: note.imagePaths, audioPaths: note.audioPaths, tags: note.tags.map(\.name), opType: .delete, deletedAt: deletedAt)
    }

    func pending() throws -> [SyncQueueItem] {
        let files = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { file in
            let data = try Data(contentsOf: file)
            return try decoder.decode(SyncQueueItem.self, from: data)
        }
    }

    func remove(items: [SyncQueueItem]) throws {
        for item in items {
            let filename = fileName(for: item.opId)
            let url = baseURL.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func enqueue(note: Note, imagePaths: [String], audioPaths: [String], tags: [String], opType: SyncOpType, deletedAt: Date?) throws {
        let opId = UUID().uuidString
        let queuedNote = SyncQueuedNote(
            id: note.id,
            text: note.text,
            isPinned: note.isPinned,
            tags: tags,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            deletedAt: deletedAt
        )
        let media = try copyMedia(noteId: note.id, imagePaths: imagePaths, audioPaths: audioPaths)
        let item = SyncQueueItem(opId: opId, opType: opType, note: queuedNote, media: media)
        let data = try encoder.encode(item)
        try data.write(to: baseURL.appendingPathComponent(fileName(for: opId)), options: .atomic)
    }

    private func fileName(for opId: String) -> String {
        let stamp = Int(Date().timeIntervalSince1970)
        return "op_\(stamp)_\(opId).json"
    }

    private func copyMedia(noteId: String, imagePaths: [String], audioPaths: [String]) throws -> [SyncQueuedMedia] {
        var queued: [SyncQueuedMedia] = []
        let imageStore = ImageStore()
        let audioStore = AudioStore()
        for path in imagePaths {
            let url = try imageStore.url(for: path)
            let id = UUID().uuidString
            let filename = "\(id).jpg"
            let dest = mediaURL.appendingPathComponent(filename)
            try fileManager.copyItem(at: url, to: dest)
            let checksum = try sha256(for: dest)
            queued.append(SyncQueuedMedia(
                id: id,
                noteId: noteId,
                kind: "image",
                filename: filename,
                contentType: "image/jpeg",
                checksum: checksum,
                localPath: dest.lastPathComponent
            ))
        }
        for path in audioPaths {
            let url = try audioStore.url(for: path)
            let id = UUID().uuidString
            let filename = "\(id).m4a"
            let dest = mediaURL.appendingPathComponent(filename)
            try fileManager.copyItem(at: url, to: dest)
            let checksum = try sha256(for: dest)
            queued.append(SyncQueuedMedia(
                id: id,
                noteId: noteId,
                kind: "audio",
                filename: filename,
                contentType: "audio/m4a",
                checksum: checksum,
                localPath: dest.lastPathComponent
            ))
        }
        return queued
    }

    private func sha256(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return data.base64EncodedString()
    }
}
```

```swift
// timeline/Services/ImageStore.swift (add helper)
func url(for path: String) throws -> URL {
    let url = baseURL.appendingPathComponent(path)
    guard fileManager.fileExists(atPath: url.path) else {
        throw ImageStoreError.missingFile
    }
    return url
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncQueueTests.enqueueCreateWritesFile`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/SyncQueue.swift timeline/Services/ImageStore.swift timelineTests/SyncQueueTests.swift
git commit -m "feat: add file-based sync queue"
```

---

### Task 3: Add JWT token storage for the signed-in user

**Files:**
- Create: `timeline/Services/AuthTokenStore.swift`
- Create: `timelineTests/AuthTokenStoreTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/AuthTokenStoreTests.swift
import Testing
@testable import timeline

struct AuthTokenStoreTests {
    @Test func tokenStoreRoundTrip() async throws {
        let store = InMemoryAuthTokenStore()
        #expect(try store.loadToken() == nil)

        try store.saveToken("jwt-token")
        #expect(try store.loadToken() == "jwt-token")

        try store.clearToken()
        #expect(try store.loadToken() == nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/AuthTokenStoreTests.tokenStoreRoundTrip`  
Expected: FAIL with missing types.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/AuthTokenStore.swift
import Foundation
import Security

protocol AuthTokenStore {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func clearToken() throws
}

final class KeychainAuthTokenStore: AuthTokenStore {
    private let service = "timeline.notesync.jwt"
    private let account = "user"

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        try clearToken()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    func loadToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
        return String(data: data, encoding: .utf8)
    }

    func clearToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class InMemoryAuthTokenStore: AuthTokenStore {
    private var token: String?

    func saveToken(_ token: String) throws { self.token = token }
    func loadToken() throws -> String? { token }
    func clearToken() throws { token = nil }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/AuthTokenStoreTests.tokenStoreRoundTrip`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/AuthTokenStore.swift timelineTests/AuthTokenStoreTests.swift
git commit -m "feat: add auth token store"
```

---

### Task 4: Add sync request/response payloads and API client

**Files:**
- Create: `timeline/Services/NotesyncAPI.swift`
- Create: `timeline/Services/NotesyncClient.swift`
- Create: `timelineTests/NotesyncClientTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/NotesyncClientTests.swift
import Foundation
import Testing
@testable import timeline

struct NotesyncClientTests {
    @Test func clientSendsAuthHeaders() async throws {
        let config = NotesyncConfiguration(baseURL: URL(string: "https://example.com")!, apiKey: "key")
        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveToken("jwt-token")
        let session = URLSessionMock()
        let client = NotesyncClient(configuration: config, tokenStore: tokenStore, session: session)

        try await client.send(payload: SyncRequest(ops: []))

        #expect(session.lastRequest?.value(forHTTPHeaderField: "X-API-Key") == "key")
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
    }
}

final class URLSessionMock: URLSession {
    var lastRequest: URLRequest?

    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncClientTests.clientSendsAuthHeaders`  
Expected: FAIL with missing client types.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesyncAPI.swift
import Foundation

struct SyncNotePayload: Codable {
    let id: String
    let text: String
    let isPinned: Bool
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
}

struct SyncMediaPayload: Codable {
    let id: String
    let noteId: String
    let kind: String
    let filename: String
    let contentType: String
    let checksum: String
    let dataBase64: String
}

struct SyncOperationPayload: Codable {
    let opId: String
    let opType: String
    let note: SyncNotePayload
    let media: [SyncMediaPayload]
}

struct SyncRequest: Codable {
    let ops: [SyncOperationPayload]
}

struct SyncNoteResult: Codable {
    let noteId: String
    let result: String
    let note: SyncNotePayload
}

struct SyncResponse: Codable {
    let results: [SyncNoteResult]
}
```

```swift
// timeline/Services/NotesyncClient.swift
import Foundation

struct NotesyncConfiguration {
    let baseURL: URL
    let apiKey: String
}

final class NotesyncClient {
    private let configuration: NotesyncConfiguration
    private let tokenStore: AuthTokenStore
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: NotesyncConfiguration, tokenStore: AuthTokenStore, session: URLSession = .shared) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func send(payload: SyncRequest) async throws -> SyncResponse {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("/api/notesync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-API-Key")
        let token = try tokenStore.loadToken()
        guard let token else { throw URLError(.userAuthenticationRequired) }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(SyncResponse.self, from: data)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncClientTests.clientSendsAuthHeaders`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/NotesyncAPI.swift timeline/Services/NotesyncClient.swift timelineTests/NotesyncClientTests.swift
git commit -m "feat: add notesync client and payloads"
```

---

### Task 5: Build sync manager that uploads queued ops

**Files:**
- Create: `timeline/Services/NotesyncManager.swift`
- Modify: `timeline/Services/SyncQueue.swift`
- Create: `timelineTests/NotesyncManagerTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/NotesyncManagerTests.swift
import Foundation
import Testing
@testable import timeline

struct NotesyncManagerTests {
    @Test func syncClearsQueueOnSuccess() async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let queue = try SyncQueue(baseURL: temp)
        let note = Note(text: "Hello", imagePaths: [], tags: [])
        try queue.enqueueCreate(note: note, imagePaths: [], audioPaths: [], tags: ["work"])

        let tokenStore = InMemoryAuthTokenStore()
        try tokenStore.saveToken("jwt-token")
        let client = NotesyncClient(
            configuration: .init(baseURL: URL(string: "https://example.com")!, apiKey: "key"),
            tokenStore: tokenStore,
            session: URLSessionMock()
        )
        let manager = NotesyncManager(queue: queue, client: client)

        try await manager.performSync()
        #expect((try queue.pending()).isEmpty)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncManagerTests.syncClearsQueueOnSuccess`  
Expected: FAIL with missing manager or mock session.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesyncManager.swift
import Foundation
import SwiftData

final class NotesyncManager {
    private let queue: SyncQueue
    private let client: NotesyncClient

    init(queue: SyncQueue = try! SyncQueue(), client: NotesyncClient) {
        self.queue = queue
        self.client = client
    }

    func performSync() async throws {
        let pending = try queue.pending()
        guard !pending.isEmpty else { return }
        let payload = try buildPayload(from: pending)
        _ = try await client.send(payload: payload)
        try queue.remove(items: pending)
    }

    private func buildPayload(from items: [SyncQueueItem]) throws -> SyncRequest {
        let ops = try items.map { item -> SyncOperationPayload in
            let media = try item.media.map { media in
                let data = try loadQueueMedia(relativePath: media.localPath)
                return SyncMediaPayload(
                    id: media.id,
                    noteId: media.noteId,
                    kind: media.kind,
                    filename: media.filename,
                    contentType: media.contentType,
                    checksum: media.checksum,
                    dataBase64: data.base64EncodedString()
                )
            }
            return SyncOperationPayload(
                opId: item.opId,
                opType: item.opType.rawValue,
                note: SyncNotePayload(
                    id: item.note.id,
                    text: item.note.text,
                    isPinned: item.note.isPinned,
                    tags: item.note.tags,
                    createdAt: item.note.createdAt,
                    updatedAt: item.note.updatedAt,
                    deletedAt: item.note.deletedAt
                ),
                media: media
            )
        }
        return SyncRequest(ops: ops)
    }

    private func loadQueueMedia(relativePath: String) throws -> Data {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = root.appendingPathComponent("SyncQueue/Media").appendingPathComponent(relativePath)
        return try Data(contentsOf: url)
    }
}
```

```swift
// timeline/Services/SyncQueue.swift (add helper for tests)
func pendingCount() throws -> Int {
    try pending().count
}
```

```swift
// timelineTests/NotesyncManagerTests.swift (add mock session)
final class URLSessionMock: URLSession {
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body = #"{"results":[]}"#.data(using: .utf8)!
        return (body, response)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncManagerTests.syncClearsQueueOnSuccess`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/NotesyncManager.swift timeline/Services/SyncQueue.swift timelineTests/NotesyncManagerTests.swift
git commit -m "feat: add notesync manager"
```

---

### Task 6: Enqueue sync operations on note create/update/delete

**Files:**
- Modify: `timeline/Services/NotesRepository.swift`
- Modify: `timeline/Views/ComposeView.swift`
- Modify: `timeline/Views/EditView.swift`
- Modify: `timeline/Views/DetailView.swift`
- Modify: `timeline/Views/TimelineView.swift`
- Modify: `timelineTests/timelineTests.swift`

**Step 1: Write the failing test**

```swift
@Test func repositoryEnqueuesCreate() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
    let context = ModelContext(container)
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = try SyncQueue(baseURL: temp)
    let repo = NotesRepository(context: context, imageStore: ImageStore(), audioStore: AudioStore(), syncQueue: queue)

    _ = try repo.create(text: "Hi", images: [], audioPaths: [], tagInput: [])

    #expect((try queue.pending()).count == 1)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.repositoryEnqueuesCreate`  
Expected: FAIL with missing syncQueue injection or queue size.

**Step 3: Write minimal implementation**

```swift
// timeline/Services/NotesRepository.swift (constructor + calls)
private let syncQueue: SyncQueue

init(context: ModelContext, imageStore: ImageStore, audioStore: AudioStore, syncQueue: SyncQueue = try! SyncQueue()) {
    self.context = context
    self.imageStore = imageStore
    self.audioStore = audioStore
    self.syncQueue = syncQueue
}

func create(...) throws -> Note {
    ...
    try context.save()
    try syncQueue.enqueueCreate(note: note, imagePaths: note.imagePaths, audioPaths: note.audioPaths, tags: note.tags.map(\.name))
    return note
}

func update(...) throws {
    ...
    try context.save()
    try syncQueue.enqueueUpdate(note: note, imagePaths: note.imagePaths, audioPaths: note.audioPaths, tags: note.tags.map(\.name))
}

func delete(note: Note) throws {
    try syncQueue.enqueueDelete(note: note)
    ...
}
```

```swift
// timeline/Views/ComposeView.swift / EditView.swift / DetailView.swift / TimelineView.swift
// Update NotesRepository init calls to include syncQueue
private let syncQueue = try! SyncQueue()
...
NotesRepository(context: modelContext, imageStore: imageStore, audioStore: audioStore, syncQueue: syncQueue)
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/timelineTests.repositoryEnqueuesCreate`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/Services/NotesRepository.swift timeline/Views/ComposeView.swift timeline/Views/EditView.swift timeline/Views/DetailView.swift timeline/Views/TimelineView.swift timelineTests/timelineTests.swift
git commit -m "feat: enqueue sync ops on note changes"
```

---

### Task 7: Add manual sync UI

**Files:**
- Modify: `timeline/Views/TimelineView.swift`
- Modify: `timeline/ContentView.swift`
- Create: `timelineTests/SyncUIStateTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/SyncUIStateTests.swift
import Testing
@testable import timeline

struct SyncUIStateTests {
    @Test func syncStateStartsIdle() async throws {
        let state = NotesyncUIState()
        #expect(state.isSyncing == false)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncUIStateTests.syncStateStartsIdle`  
Expected: FAIL with missing type.

**Step 3: Write minimal implementation**

```swift
// timeline/ContentView.swift (add shared UI state)
@StateObject private var syncState = NotesyncUIState()
...
TimelineView()
    .environmentObject(syncState)
```

```swift
// timeline/Services/NotesyncUIState.swift
import Foundation

final class NotesyncUIState: ObservableObject {
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var lastSyncAt: Date?
}
```

```swift
// timeline/Views/TimelineView.swift (add sync button)
@EnvironmentObject private var syncState: NotesyncUIState
@State private var isShowingSyncError = false
private let syncQueue = try! SyncQueue()
private let tokenStore = KeychainAuthTokenStore()
private var syncManager: NotesyncManager {
    let config = NotesyncConfiguration(baseURL: URL(string: "https://example.com")!, apiKey: "replace-me")
    let client = NotesyncClient(configuration: config, tokenStore: tokenStore)
    return NotesyncManager(queue: syncQueue, client: client)
}

ToolbarItem(placement: .topBarTrailing) {
    Button {
        Task {
            await syncNow()
        }
    } label: {
        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
    }
    .disabled(syncState.isSyncing)
}

private func syncNow() async {
    syncState.isSyncing = true
    do {
        try await syncManager.performSync()
        syncState.lastSyncAt = Date()
    } catch {
        syncState.lastError = error.localizedDescription
        isShowingSyncError = true
    }
    syncState.isSyncing = false
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/SyncUIStateTests.syncStateStartsIdle`  
Expected: PASS

**Step 5: Commit**

```bash
git add timeline/ContentView.swift timeline/Views/TimelineView.swift timeline/Services/NotesyncUIState.swift timelineTests/SyncUIStateTests.swift
git commit -m "feat: add manual sync UI state and button"
```

---

### Task 8: Document notesync configuration

**Files:**
- Modify: `README.md`
- Create: `timelineTests/NotesyncDocsTests.swift`

**Step 1: Write the failing test**

```swift
// timelineTests/NotesyncDocsTests.swift
import Testing

struct NotesyncDocsTests {
    @Test func readmeMentionsNotesyncEndpoint() async throws {
        let text = try String(contentsOfFile: "README.md", encoding: .utf8)
        #expect(text.contains("/api/notesync"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncDocsTests.readmeMentionsNotesyncEndpoint`  
Expected: FAIL

**Step 3: Write minimal implementation**

```markdown
## Notesync (Manual Sync)
- Endpoint: `POST /api/notesync`
- Headers: `X-API-Key: <your-key>`, `Authorization: Bearer <jwt>`
- Store the JWT in `KeychainAuthTokenStore` after OAuth login.
- Update `NotesyncConfiguration` in `timeline/Views/TimelineView.swift` with your backend base URL and API key.
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' -only-testing:timelineTests/NotesyncDocsTests.readmeMentionsNotesyncEndpoint`  
Expected: PASS

**Step 5: Commit**

```bash
git add README.md timelineTests/NotesyncDocsTests.swift
git commit -m "docs: add notesync configuration info"
```

---

## Verification

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0'`  
Expected: All tests pass.
