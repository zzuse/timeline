# Timeline Notes - Android

Android version of the Timeline Notes app built with Flutter/Dart.

## Features

### Core Note-Taking
- ✅ Create, edit, delete notes with timestamps
- ✅ Photo capture and image attachments
- ✅ Audio recording and playback
- ✅ Tag-based organization
- ✅ Search and filter
- ✅ Pin important notes
- ✅ Swipe actions (pin, delete)

### Cloud Sync (Phase 2 & 3)
- ✅ OAuth 2.0 authentication
- ✅ Automatic background sync
- ✅ Text content sync
- ✅ **Media sync (images/audio)** via base64 encoding
- ✅ Offline queue with retry logic
- ✅ Conflict resolution (server-wins or last-write-wins)

## Architecture

### Data Layer
- **SQLite** for local note storage
- **ImageStore/AudioStore** for media file management
- **NotesRepository** for data access abstraction

### Sync Layer
- **AuthSessionManager** - OAuth token management
- **NotesyncClient** - API communication
- **SyncEngine** - Orchestrates sync operations
- **SyncQueue** - File-based offline queue with media support
- **MediaUtils** - SHA256 checksums and base64 encoding

### UI
- Material Design components
- Provider for state management
- Custom widgets for notes, tags, and media

## Setup

See [commands.md](commands.md) for detailed setup instructions.

### Quick Start
```bash
# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

## Configuration

Update [lib/config/sync_config.dart](lib/config/sync_config.dart) with your server details:
```dart
static const baseUrl = 'https://your-server.com';
static const apiKey = 'your-api-key';
```

## Testing Media Sync

1. Sign in with OAuth
2. Create note with image/audio
3. Tap "Sync Now"
4. Check server logs for media upload
5. Test download on another device

See [docs/media_sync_walkthrough.md](docs/media_sync_walkthrough.md) for architecture details.

## Documentation

- [commands.md](commands.md) - Setup and development commands
- [docs/walkthrough.md](docs/walkthrough.md) - Complete development walkthrough
- [docs/media_sync_walkthrough.md](docs/media_sync_walkthrough.md) - Phase 3 media sync details
- [docs/phase2_walkthrough.md](docs/phase2_walkthrough.md) - Phase 2 technical details

## Dependencies

Key packages:
- `sqflite` - SQLite database
- `image_picker` - Camera/gallery access
- `audioplayers` - Audio playback
- `record` - Audio recording
- `http` - Network requests
- `flutter_secure_storage` - Secure token storage
- `crypto` - SHA256 checksums for media
- `connectivity_plus` - Network status

## Known Limitations

- Base64 encoding increases payload size by ~33%
- Large files (>10MB) may cause memory issues
- No chunked uploads for large media
- Server-wins conflict resolution for media

## License

[Add your license here]
