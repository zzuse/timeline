# Android Timeline Notes App Implementation Plan

A local-first Android app for short personal notes, mirroring the iOS Timeline app. Create quick entries with photos, tags, and voice recordings, then browse chronologically with pinning and search.

## User Review Required

> [!IMPORTANT]
> **Technology Stack Decisions**:
> - **Flutter + Dart** for cross-platform development with declarative UI
> - **SQLite (sqflite)** or **Drift** for local storage
> - **Material 3** design system
> - **Min SDK**: Android 11+ (API 30+)

> [!WARNING]
> **Sync Features**: The iOS app has OAuth sync features. Should I include these in the initial Android version, or focus on the local-first core features first?

---

## Proposed Changes

### Project Setup

#### [NEW] `app/build.gradle.kts`
Configure dependencies:
- Jetpack Compose BOM
- Room database
- Navigation Compose
- CameraX for camera
- Coil for image loading
- Media3 for audio playback

#### [NEW] Basic project structure:
```
app/src/main/java/com/zzuse/timeline/
├── MainActivity.kt
├── TimelineApp.kt
├── data/
│   ├── local/
│   │   ├── TimelineDatabase.kt
│   │   ├── NoteDao.kt
│   │   ├── TagDao.kt
│   │   ├── entities/
│   │   │   ├── NoteEntity.kt
│   │   │   └── TagEntity.kt
│   │   └── converters/
│   │       └── DateConverters.kt
│   └── repository/
│       ├── NotesRepository.kt
│       ├── ImageStore.kt
│       └── AudioStore.kt
├── ui/
│   ├── theme/
│   │   ├── Theme.kt
│   │   ├── Color.kt
│   │   └── Type.kt
│   ├── navigation/
│   │   └── TimelineNavGraph.kt
│   ├── screens/
│   │   ├── timeline/
│   │   │   └── TimelineScreen.kt
│   │   ├── compose/
│   │   │   └── ComposeScreen.kt
│   │   ├── detail/
│   │   │   └── DetailScreen.kt
│   │   ├── edit/
│   │   │   └── EditScreen.kt
│   │   ├── settings/
│   │   │   └── SettingsScreen.kt
│   │   └── search/
│   │       └── SearchFilterScreen.kt
│   └── components/
│       ├── NoteRow.kt
│       ├── TagInputField.kt
│       ├── ImageGrid.kt
│       ├── AudioClipRow.kt
│       └── CameraCapture.kt
└── viewmodel/
    ├── TimelineViewModel.kt
    ├── ComposeViewModel.kt
    └── DetailViewModel.kt
```

---

### Data Layer

#### [NEW] `NoteEntity.kt`
```kotlin
@Entity(tableName = "notes")
data class NoteEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val text: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val isPinned: Boolean = false,
    val imagePaths: String = "",  // JSON array of paths
    val audioPaths: String = ""   // JSON array of paths
)
```

#### [NEW] `TagEntity.kt`
```kotlin
@Entity(tableName = "tags")
data class TagEntity(
    @PrimaryKey val name: String
)
```

#### [NEW] `NoteTagCrossRef.kt`
Many-to-many relationship between notes and tags.

#### [NEW] `ImageStore.kt`
- Save images as JPEG to app's internal storage
- Load images by path
- Delete images

#### [NEW] `AudioStore.kt`
- Create recording file URLs
- Delete audio files

---

### UI Layer - Screens

#### [NEW] `TimelineScreen.kt`
Main screen features:
- List notes with pinned section first
- Swipe actions: edit, pin, delete
- FAB to compose new note
- Toolbar with filter, sync, settings buttons
- Empty state with "Create your first note"

#### [NEW] `ComposeScreen.kt`
- TextEditor for note content
- Photo picker + camera button
- Audio recording controls
- Tag input with autocomplete
- Save/Cancel actions

#### [NEW] `DetailScreen.kt`
- Display note content, images, audio, tags
- Edit, pin, delete actions in toolbar
- Timestamps display

#### [NEW] `EditScreen.kt`
- Pre-populated fields for editing
- Same layout as ComposeScreen

#### [NEW] `SearchFilterScreen.kt`
- Search text input
- Tag filter chips
- Apply/clear buttons

#### [NEW] `SettingsScreen.kt`
- Account section (login/logout)
- Sync status display
- Full resync option

---

### UI Components

#### [NEW] `NoteRow.kt`
- Thumbnail image if available
- Note text (3 line limit)
- Tag chips
- Audio clip count indicator
- Timestamp

#### [NEW] `AudioClipRow.kt`
- Playback button with play/stop states
- Title label
- Optional delete button

#### [NEW] `ImageGrid.kt`
- Grid layout for multiple images
- Tap to view fullscreen
- Optional delete overlay

#### [NEW] `TagInputField.kt`
- Text field with chip display
- Autocomplete suggestions from existing tags

---

## Feature Parity Matrix

| Feature | iOS | Android (Planned) |
|---------|-----|-------------------|
| Create notes | ✅ | ✅ |
| Text, images, audio | ✅ | ✅ |
| Tags with autocomplete | ✅ | ✅ |
| Pin notes | ✅ | ✅ |
| Search/filter | ✅ | ✅ |
| Camera capture | ✅ | ✅ |
| Audio recording | ✅ | ✅ |
| Audio playback | ✅ | ✅ |
| Local storage | ✅ | ✅ |
| Swipe actions | ✅ | ✅ |
| OAuth sync | ✅ | Phase 2 |

---

## Verification Plan

### Automated Tests

1. **Unit Tests for Repository**
```bash
./gradlew testDebugUnitTest --tests "*NotesRepositoryTest*"
```
- Test CRUD operations on notes
- Test tag normalization
- Test image/audio path handling

2. **Instrumentation Tests for Database**
```bash
./gradlew connectedAndroidTest --tests "*DatabaseTest*"
```
- Test Room DAOs
- Test entity relationships

3. **UI Tests for Main Flows**
```bash
./gradlew connectedAndroidTest --tests "*TimelineScreenTest*"
```
- Test creating a new note
- Test editing a note
- Test deleting a note
- Test pin/unpin

### Manual Verification

1. **Build and Run**
```bash
./gradlew assembleDebug
# Install on device/emulator and verify app launches
```

2. **Core Flow Testing**
- Create a note with text → verify appears in timeline
- Add images from gallery → verify display in note
- Take photo with camera → verify saved and displayed
- Record audio → verify playback works
- Add tags → verify chips display
- Pin/unpin → verify sort order changes
- Delete note → verify removed from list

3. **Search and Filter**
- Search by text → verify results
- Filter by tag → verify filtering works

---

## Questions for User

1. **Package name**: Is `com.zzuse.timeline` acceptable, or do you prefer a different package?

2. **Min SDK**: Android 13 (API 33) matches iOS 17 requirement. Should I support older Android versions?

3. **Sync features**: Include OAuth sync in Phase 1, or focus on local-first features first?

4. **Project location**: Should I create the Android project in `/Users/z/Documents/Code/Self/timeline/timelineAndroid/android/` or a different location?
