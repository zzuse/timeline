# Personal Timeline Notes (iOS) - Design

## Overview
Build a local-first personal timeline notes app for iOS 17+ using SwiftUI + SwiftData. Users can post short notes with images, audio clips, and tags, browse a timeline, search/filter by text and tags, and edit/delete/pin notes. Images and audio are stored on disk; SwiftData stores metadata and paths. Manual sync uploads notes to a backend after login, with diagnostics, batching, and a settings sheet for account/sync actions.

## Goals
- Post short notes with images (camera + photo library), audio clips, and tags.
- Timeline browsing with pinned-first ordering, then creation time descending.
- Search by text and filter by tags.
- Edit, delete, and pin/unpin notes.
- Local-first storage with manual sync after sign-in.
- Settings sheet with Logout, Full Resync, and sync status.
- Empty-state “Restore latest 10” action for reinstall scenarios.

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
- NotesyncClient/NotesyncManager handle API requests; AuthSessionManager handles login and token exchange.
- Sync payloads include media bytes as base64 and SHA-256 checksums; uploads are batched under 10 MB.
- Keychain-backed token storage for JWT access tokens.

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
- LoginView: external browser login entry point.
- SettingsView: Logout, Full Resync, and sync status (last sync/error).
- Empty-state Restore action when no local notes exist and user is signed in.

## Data Flow
Create/Edit:
- User picks images -> ImageStore compresses and saves -> returns paths.
- NotesRepository normalizes tags, updates updatedAt, persists Note via SwiftData.
Sync (manual):
- User signs in via external browser; app receives a custom URL scheme callback and stores JWT.
- User taps Sync; queued changes upload to backend using API key + JWT.
- Sync batches payloads to stay under 10 MB.
- Empty-state Restore action fetches the latest 10 notes after login.
- Full Resync (Settings): enqueue all local notes for upload to rebuild the server.

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
- Sync failures surface server errors; token_expired prompts re-login.
- Full Resync failures keep the queue intact for retry.

## Testing
- ImageStoreTests: save/load/delete and idempotent delete.
- TagNormalizationTests: trim, lowercase, dedupe.
- NotesRepositoryTests: CRUD, updatedAt, isPinned, image path handling.
- FilteringTests: text + tag filtering logic.
- UITest smoke: create note, add image, pin, confirm order.
- NotesyncClient/Manager tests: auth headers, queue handling.
- SyncQueue tests: checksum correctness and queue behavior.
- Auth flow tests: callback parsing and token persistence.

## Future Extension
- Replace ImageStore with remote upload and map paths to URLs for sync.
- Add multi-tab navigation (Timeline/Tags/Search).
- Add refresh-token support and server-side media deduplication.
