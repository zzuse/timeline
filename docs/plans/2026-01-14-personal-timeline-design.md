# Personal Timeline Notes (iOS) - Design

## Overview
Build a local-first personal timeline notes app for iOS 17+ using SwiftUI + SwiftData. Users can post short notes with images, audio clips, and tags, browse a timeline, search/filter by text and tags, and edit/delete/pin notes. Images and audio are stored on disk; SwiftData stores metadata and paths. Optional manual sync uploads notes to a backend when the user signs in.

## Goals
- Post short notes with images (camera + photo library), audio clips, and tags.
- Timeline browsing with pinned-first ordering, then creation time descending.
- Search by text and filter by tags.
- Edit, delete, and pin/unpin notes.
- Local-first storage with optional manual sync.

## Non-Goals (MVP)
- Rich text, mentions, or comments.
- Tag management screen beyond autocomplete.
### Deferred
- Background or automatic sync.
- Multi-device conflict resolution beyond last-write-wins.

## Architecture
- SwiftUI views for timeline, detail, compose/edit, search/filter, and a login entry point.
- SwiftData models for Note and Tag; local file stores for images/audio.
- ImageStore writes compressed JPEG files to Documents/Images and returns relative paths.
- NotesRepository coordinates SwiftData CRUD and ImageStore file operations.
- File-based sync queue and manual sync action when authenticated.

## Data Model
Note
- id: UUID
- text: String
- createdAt: Date
- updatedAt: Date
- isPinned: Bool
- imagePaths: [String]
- audioPaths: [String]
- tags: [Tag]

Tag
- id: UUID
- name: String (normalized lowercased)

## UI Components
- TimelineView: list with sections (Pinned, All). Uses SwiftData query sorting by isPinned desc, createdAt desc.
- NoteRow: text preview, first image thumbnail, audio indicator, tag chips, timestamp.
- DetailView: full text, image grid, audio playback, tags, metadata; actions for edit/delete/pin.
- ComposeView (full-screen): TextEditor, image picker (camera + library), audio recording, tag input with autocomplete, Save/Cancel.
- EditView: same as Compose, prefilled, manage audio clips.
- SearchFilterView: text field and tag chips; applies predicate or in-memory filter.
- ImageGrid: 1-4 images layout (2x2).

## Data Flow
Create/Edit:
- User picks images -> ImageStore compresses and saves -> returns paths.
- NotesRepository normalizes tags, updates updatedAt, persists Note via SwiftData.
Sync (manual):
- User signs in via external browser; app receives universal link callback and stores JWT.
- User taps Sync; queued changes upload to backend using API key + JWT.

Delete:
- Repository deletes Note from SwiftData, removes associated image files.
- Optional cleanup of orphan tags (defer for MVP).

Query:
- Default: sort by isPinned then createdAt desc.
- Search: text contains (case-insensitive) and tags match selected tags.

## Error Handling
- Image save failures show a user-facing alert; keep draft intact.
- SwiftData write failures show alert; allow retry.
- Delete failures: remove Note, but warn if some files fail to delete.
- Camera/Photos permission denial shows in-app explanation and link to Settings.

## Testing
- ImageStoreTests: save/load/delete and idempotent delete.
- TagNormalizationTests: trim, lowercase, dedupe.
- NotesRepositoryTests: CRUD, updatedAt, isPinned, image path handling.
- FilteringTests: text + tag filtering logic.
- UITest smoke: create note, add image, pin, confirm order.

## Future Extension
- Replace ImageStore with remote upload and map paths to URLs for sync.
- Add multi-tab navigation (Timeline/Tags/Search).
