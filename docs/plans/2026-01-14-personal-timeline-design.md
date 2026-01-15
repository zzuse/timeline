# Personal Timeline Notes (iOS) - Design

## Overview
Build a local-only personal timeline notes app for iOS 17+ using SwiftUI + SwiftData. Users can post short notes with images and tags, browse a timeline, search/filter by text and tags, and edit/delete/pin notes. Images are stored on disk; SwiftData stores metadata and paths.

## Goals
- Post short notes with images (camera + photo library) and tags.
- Timeline browsing with pinned-first ordering, then creation time descending.
- Search by text and filter by tags.
- Edit, delete, and pin/unpin notes.
- Pure local storage; no network.

## Non-Goals (MVP)
- Remote sync or accounts.
- Rich text, mentions, or comments.
- Tag management screen beyond autocomplete.

## Architecture
- SwiftUI views for timeline, detail, compose/edit, and search/filter.
- SwiftData models for Note and Tag.
- ImageStore writes compressed JPEG files to Documents/Images and returns relative paths.
- NotesRepository coordinates SwiftData CRUD and ImageStore file operations.
- Simple in-memory caching (NSCache) for image loading.

## Data Model
Note
- id: UUID
- text: String
- createdAt: Date
- updatedAt: Date
- isPinned: Bool
- imagePaths: [String]
- tags: [Tag]

Tag
- id: UUID
- name: String (normalized lowercased)

## UI Components
- TimelineView: list with sections (Pinned, All). Uses SwiftData query sorting by isPinned desc, createdAt desc.
- NoteRow: text preview, first image thumbnail, tag chips, timestamp.
- DetailView: full text, image grid, tags, metadata; actions for edit/delete/pin.
- ComposeView (full-screen): TextEditor, image picker (camera + library), tag input with autocomplete, Save/Cancel.
- EditView: same as Compose, prefilled.
- SearchFilterView: text field and tag chips; applies predicate or in-memory filter.
- ImageGrid: 1-4 images layout (2x2).

## Data Flow
Create/Edit:
- User picks images -> ImageStore compresses and saves -> returns paths.
- NotesRepository normalizes tags, updates updatedAt, persists Note via SwiftData.

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
