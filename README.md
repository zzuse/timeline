# Timeline Notes

A local-first iOS app for short personal notes, similar to a lightweight timeline. Create quick entries with photos, tags, and optional voice recordings, then browse them chronologically with pinning and search.

## Features
- Short notes with text, images, and audio clips
- Tags with autocomplete and filtering
- Pinned notes shown first, then newest-to-oldest
- Detail view with edit/delete/pin actions
- Local-first storage with optional manual sync

## Tech Stack
- SwiftUI + SwiftData
- iOS 17+ (Xcode 16+)
- PhotosPicker and Camera
- AVFoundation for audio recording/playback

## Data Storage
- SwiftData stores note metadata and media paths
- Images are saved as JPEGs under Documents/Images
- Audio clips are saved as M4A under Documents/Audio

## Requirements
- macOS with Xcode 16+
- iOS Simulator or device running iOS 17+

## Run
1. Open `timeline.xcodeproj` in Xcode.
2. Select a simulator or device.
3. Build and run the `timeline` scheme.

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
- Store the JWT in `KeychainAuthTokenStore` after code exchange.
- Update `AppConfiguration.default` in `timeline/Services/AppConfiguration.swift` with your backend base URL and API key.
