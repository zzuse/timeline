# Timeline Notes

A local-first cross-platform app for short personal notes, similar to a lightweight timeline. Create quick entries with photos, tags, and optional voice recordings, then browse them chronologically with pinning and search.

## Features
- Short notes with text, images, and audio clips
- Tags with autocomplete and filtering
- Pinned notes shown first, then newest-to-oldest
- Detail view with edit/delete/pin actions
- Local-first storage with optional manual sync (NoteSync)
- **Cross-Platform**: Available on iOS (SwiftUI) and Android (Flutter)

## Tech Stack

### iOS
- SwiftUI + SwiftData
- iOS 17+ (Xcode 16+)
- PhotosPicker and Camera
- AVFoundation for audio recording/playback

### Android
- Flutter + Dart
- SQLite (sqflite)
- Material 3 Design
- `audioplayers` / `record` packages

## Data Storage
- **iOS**: SwiftData stores note metadata and media paths
- **Android**: SQLite stores note metadata
- Images are saved as JPEGs locally
- Audio clips are saved as M4A locally

## Requirements
- **iOS**: macOS with Xcode 16+
- **Android**: Flutter SDK, Android Studio/VSCode

## Run

### iOS
1. Open `timeline.xcodeproj` in Xcode.
2. Select a simulator or device.
3. Build and run the `timeline` scheme.

### Android
1. Navigate to `timelineAndroid` directory:
   ```bash
   cd timelineAndroid
   ```
2. Follow instructions in [timelineAndroid/README.md](timelineAndroid/README.md).


## Tests
```bash
xcodebuild test -scheme timeline -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0'
```

## Notes
- The app requests microphone access to record audio notes.
- All data stays on-device; deleting a note removes its media files.

## Notesync (Manual Sync)
- Endpoint: `POST /api/notesync`
- Headers: `X-API-Key: <your-key>`, `Authorization: Bearer <jwt>`
- Login URL: `https://zzuse.duckdns.org/login` (opens in external browser).
- OAuth callback: `zzuse.timeline://auth/callback?code=...`
- Code exchange: `POST /api/auth/exchange` with `{ "code": "..." }`
- Refresh: `POST /auth/refresh` with the refresh token to get new tokens.
- Access + refresh tokens are returned during code exchange and stored in `KeychainAuthTokenStore`.
- Max request size: 10 MB. Client batches sync uploads to stay under the limit.
- Update `AppConfiguration.default` in `timeline/Services/AppConfiguration.swift` with your backend base URL, API key, and callback scheme/host/path.
