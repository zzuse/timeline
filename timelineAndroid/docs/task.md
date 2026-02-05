# Android Timeline App Development

## Overview
Develop an Android version of the iOS Timeline Notes app using Flutter/Dart.

## Tasks

### Planning Phase
- [x] Analyze iOS app structure and features
- [x] Create implementation plan
- [x] Get user approval on implementation plan

### Project Setup
- [x] Create Flutter project with Dart
- [x] Configure dependencies for local storage
- [x] Set up project structure (models, ui, data, services)
- [x] Configure Android permissions (camera, mic, storage)
- [x] Set min SDK to 30 (Android 11+)

### Data Layer
- [x] Create Note model
- [x] Create DatabaseHelper with SQLite
- [x] Create NotesRepository
- [x] Implement ImageStore for image file management
- [x] Implement AudioStore for audio file management

### UI Layer - Core Screens
- [x] Implement TimelineScreen (main list view)
- [x] Implement ComposeScreen (create new note)
- [x] Implement DetailScreen (view single note)
- [x] Implement EditScreen (edit existing note)

### UI Layer - Supporting Screens
- [x] Implement SearchScreen (search and filter)
- [x] Implement SettingsScreen

### UI Components
- [x] NoteRow widget
- [x] TagInputField widget
- [x] ImageGrid widget
- [x] AudioClipRow with playback

### Features
- [x] Photo picker integration
- [x] Camera capture
- [x] Audio recording
- [x] Audio playback
- [x] Tag input
- [x] Search and filter
- [x] Pin/unpin notes
- [x] Swipe actions (pin, delete)

### Testing & Verification
- [x] Verify build compiles
- [x] Test on device/emulator

### Unit Tests (TDD)
- [x] Create test suite plan
- [x] Implement Note model tests
- [x] Implement MediaUtils tests
- [x] Implement NotesyncClient tests
- [x] Implement SyncQueue tests
- [x] Implement DatabaseHelper tests
- [x] Implement NotesRepository tests
- [x] Implement ImageStore tests
- [x] Implement SyncEngine tests

### Phase 2: Sync Services
- [x] Create implementation plan for sync features
- [x] Analyze iOS implementation for API details
- [x] Update sync config with actual endpoints
- [x] Update Note model with sync fields
- [x] Update database schema (add sync columns)
- [x] Implement AuthSessionManager
- [x] Implement NotesyncClient (API client)
- [x] Implement SyncEngine (orchestrator)
- [x] Implement SyncQueue (offline queue)
- [x] Update UI with sync indicators
- [x] Fix deep link OAuth callback (native MethodChannel)
- [x] Fix TokenResponse parsing (snake_case field names)
- [x] Test OAuth flow end-to-end
- [x] Test text sync (create/update/delete)

### Phase 3: Media Sync
- [x] Review and approve media sync implementation plan
- [x] Add crypto package for SHA256 checksums
- [x] Update sync models (add SyncMediaPayload)
- [x] Update SyncQueue to handle media files
- [x] Update SyncEngine upload with base64 encoding
- [x] Update SyncEngine download with base64 decoding
- [x] Create media_utils.dart helper
- [x] App compiles and runs successfully
- [x] Test image sync end-to-end
- [x] Test audio sync end-to-end
- [x] Test large file handling
