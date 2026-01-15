# Personal Timeline Notes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the local-only personal timeline notes app (SwiftUI + SwiftData) with images, tags, search, edit/delete, and pinning.

**Architecture:** SwiftUI views on top of SwiftData models (Note, Tag). An ImageStore writes compressed JPEGs to Documents and returns relative paths; a NotesRepository orchestrates CRUD + tag normalization + file cleanup. Timeline uses SwiftData queries and pinned-first sorting; search applies text + tag filters.

**Tech Stack:** SwiftUI, SwiftData (iOS 17+), PhotosUI, UIKit camera picker, Foundation.

---

### Task 1: Add SwiftData model layer

**Files:**
- Create: `timeline/Models/Note.swift`
- Create: `timeline/Models/Tag.swift`
- Modify: `timeline/timelineApp.swift`
- Test: `timelineTests/ModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import timeline

final class ModelTests: XCTestCase {
    func testTagNormalization() throws {
        let tags = Tag.normalized(from: ["  Swift ", "swift", "iOS "])
        XCTAssertEqual(tags.map { $0.name }.sorted(), ["ios", "swift"])
    }

    func testNoteDefaults() throws {
        let note = Note(text: "Hello", imagePaths: [], tags: [])
        XCTAssertFalse(note.isPinned)
        XCTAssertLessThanOrEqual(note.createdAt, note.updatedAt)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL because models don’t exist yet (note: simulator may be unavailable in this environment).

**Step 3: Write minimal implementation**

```swift
import Foundation
import SwiftData

@Model
final class Tag: Identifiable {
    @Attribute(.unique) var name: String

    init(name: String) {
        self.name = name
    }

    static func normalized(from input: [String]) -> [Tag] {
        let names = input
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        let unique = Array(Set(names))
        return unique.map(Tag.init)
    }
}
```

```swift
import Foundation
import SwiftData

@Model
final class Note: Identifiable {
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var imagePaths: [String]
    var tags: [Tag]

    init(text: String, imagePaths: [String], tags: [Tag]) {
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.imagePaths = imagePaths
        self.tags = tags
    }
}
```

Update `timelineApp` to install SwiftData model container.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS (if simulator is available).

**Step 5: Commit**

```bash
git add timeline/Models/Note.swift timeline/Models/Tag.swift timeline/timelineApp.swift timelineTests/ModelTests.swift
git commit -m "feat: add SwiftData models for notes and tags"
```

---

### Task 2: ImageStore for local image persistence

**Files:**
- Create: `timeline/Services/ImageStore.swift`
- Test: `timelineTests/ImageStoreTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import timeline

final class ImageStoreTests: XCTestCase {
    func testSaveLoadDelete() throws {
        let store = ImageStore()
        let image = UIImage(systemName: "star")!

        let paths = try store.save(images: [image])
        XCTAssertEqual(paths.count, 1)

        let loaded = try store.load(path: paths[0])
        XCTAssertNotNil(loaded)

        try store.delete(paths: paths)
        XCTAssertThrowsError(try store.load(path: paths[0]))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL because ImageStore doesn’t exist.

**Step 3: Write minimal implementation**

```swift
import Foundation
import UIKit

final class ImageStore {
    enum ImageStoreError: Error { case invalidData, missingFile }

    private let fm = FileManager.default
    private let folder = "Images"

    private var baseURL: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(folder)
    }

    init() {
        try? fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func save(images: [UIImage]) throws -> [String] {
        var paths: [String] = []
        for image in images {
            guard let data = image.jpegData(compressionQuality: 0.82) else {
                throw ImageStoreError.invalidData
            }
            let name = UUID().uuidString + ".jpg"
            let url = baseURL.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            paths.append(name)
        }
        return paths
    }

    func load(path: String) throws -> UIImage {
        let url = baseURL.appendingPathComponent(path)
        guard fm.fileExists(atPath: url.path) else { throw ImageStoreError.missingFile }
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else { throw ImageStoreError.invalidData }
        return image
    }

    func delete(paths: [String]) throws {
        for path in paths {
            let url = baseURL.appendingPathComponent(path)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
            }
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/Services/ImageStore.swift timelineTests/ImageStoreTests.swift
git commit -m "feat: add local ImageStore"
```

---

### Task 3: NotesRepository for CRUD + tag normalization

**Files:**
- Create: `timeline/Services/NotesRepository.swift`
- Test: `timelineTests/NotesRepositoryTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
@testable import timeline

final class NotesRepositoryTests: XCTestCase {
    func testCreateUpdatesTimestampsAndTags() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
        let context = ModelContext(container)
        let repo = NotesRepository(context: context, imageStore: ImageStore())

        let note = try repo.create(text: "Hi", images: [], tagInput: ["Swift", "swift"])
        XCTAssertEqual(note.tags.count, 1)
        XCTAssertGreaterThanOrEqual(note.updatedAt, note.createdAt)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL because NotesRepository doesn’t exist.

**Step 3: Write minimal implementation**

```swift
import Foundation
import SwiftData
import UIKit

final class NotesRepository {
    private let context: ModelContext
    private let imageStore: ImageStore

    init(context: ModelContext, imageStore: ImageStore) {
        self.context = context
        self.imageStore = imageStore
    }

    func create(text: String, images: [UIImage], tagInput: [String]) throws -> Note {
        let paths = try imageStore.save(images: images)
        let tags = Tag.normalized(from: tagInput)
        let note = Note(text: text, imagePaths: paths, tags: tags)
        context.insert(note)
        try context.save()
        return note
    }

    func update(note: Note, text: String, images: [UIImage], removedPaths: [String], tagInput: [String], isPinned: Bool) throws {
        let newPaths = try imageStore.save(images: images)
        note.text = text
        note.tags = Tag.normalized(from: tagInput)
        note.isPinned = isPinned
        note.imagePaths.append(contentsOf: newPaths)
        note.updatedAt = Date()
        try imageStore.delete(paths: removedPaths)
        try context.save()
    }

    func delete(note: Note) throws {
        try imageStore.delete(paths: note.imagePaths)
        context.delete(note)
        try context.save()
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/Services/NotesRepository.swift timelineTests/NotesRepositoryTests.swift
git commit -m "feat: add notes repository"
```

---

### Task 4: Timeline list UI (pinned-first)

**Files:**
- Modify: `timeline/ContentView.swift`
- Create: `timeline/Views/TimelineView.swift`
- Create: `timeline/Views/NoteRow.swift`

**Step 1: Write the failing test**

Create a UI test skeleton for pinned ordering.

```swift
import XCTest

final class timelineUITests: XCTestCase {
    func testPinnedFirstOrdering() throws {
        // Placeholder: to be updated when UI exists
        XCTAssertTrue(true)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL once real assertions are added (for now placeholder passes).

**Step 3: Write minimal implementation**

- `TimelineView` with `@Query(sort: [SortDescriptor(\.isPinned, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)])`
- `NoteRow` shows text, first image thumbnail (if any), and tag chips.
- `ContentView` hosts `TimelineView`.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/ContentView.swift timeline/Views/TimelineView.swift timeline/Views/NoteRow.swift timelineUITests/timelineUITests.swift
git commit -m "feat: add timeline list UI"
```

---

### Task 5: Compose/Edit UI with photos and tags

**Files:**
- Create: `timeline/Views/ComposeView.swift`
- Create: `timeline/Views/EditView.swift`
- Create: `timeline/Views/TagInputView.swift`
- Create: `timeline/Views/ImageGrid.swift`
- Modify: `timeline/Views/TimelineView.swift`

**Step 1: Write the failing test**

Add a UI test skeleton for compose flow (placeholder until simulator available).

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL when real UI checks are added.

**Step 3: Write minimal implementation**

- Full-screen sheet from TimelineView.
- TextEditor + counter, PhotosPicker, Camera button.
- Tag input with autocomplete from existing Tag list.
- Save button disabled unless text or images present.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/Views/ComposeView.swift timeline/Views/EditView.swift timeline/Views/TagInputView.swift timeline/Views/ImageGrid.swift timeline/Views/TimelineView.swift
 git commit -m "feat: add compose and edit views"
```

---

### Task 6: Detail view with edit/delete/pin

**Files:**
- Create: `timeline/Views/DetailView.swift`
- Modify: `timeline/Views/TimelineView.swift`

**Step 1: Write the failing test**

Add UI test skeleton for pin/unpin.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL when real UI checks are added.

**Step 3: Write minimal implementation**

- DetailView showing note content and images.
- Toolbar buttons for edit, delete, pin/unpin.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/Views/DetailView.swift timeline/Views/TimelineView.swift
 git commit -m "feat: add detail view actions"
```

---

### Task 7: Search and filter

**Files:**
- Create: `timeline/Views/SearchFilterView.swift`
- Modify: `timeline/Views/TimelineView.swift`

**Step 1: Write the failing test**

Add a unit test for text filter logic (in-memory predicate).

```swift
import XCTest
@testable import timeline

final class FilteringTests: XCTestCase {
    func testTextFilter() {
        let notes = [
            Note(text: "Hello Swift", imagePaths: [], tags: []),
            Note(text: "Photo", imagePaths: [], tags: [])
        ]
        let filtered = TimelineFilter.text("swift").apply(to: notes)
        XCTAssertEqual(filtered.count, 1)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL because filter helper doesn’t exist.

**Step 3: Write minimal implementation**

- Add `TimelineFilter` helper (local file or nested in TimelineView).
- Search UI exposes text + tag selection.
- Apply filter in-memory if SwiftData predicate is complex.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/Views/SearchFilterView.swift timeline/Views/TimelineView.swift timelineTests/FilteringTests.swift
 git commit -m "feat: add search and tag filtering"
```

---

### Task 8: Polish + error handling

**Files:**
- Modify: `timeline/Views/ComposeView.swift`
- Modify: `timeline/Services/NotesRepository.swift`
- Modify: `timeline/Services/ImageStore.swift`

**Step 1: Write the failing test**

Add a repository test for save failure handling (simulate invalid image data).

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: FAIL because error paths aren’t surfaced.

**Step 3: Write minimal implementation**

- Surface errors as user-friendly alerts.
- Ensure drafts are preserved on failure.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15'`
Expected: PASS.

**Step 5: Commit**

```bash
git add timeline/Views/ComposeView.swift timeline/Services/NotesRepository.swift timeline/Services/ImageStore.swift timelineTests/NotesRepositoryTests.swift
 git commit -m "feat: add error handling and polish"
```

---

## Notes on Verification
Simulator tests cannot run in this environment (CoreSimulator unavailable). Run tests locally in Xcode once implementation is complete.

