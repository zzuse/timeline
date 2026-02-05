# Android vs iOS Implementation Differences

This document outlines the key differences between the Android and iOS Timeline app implementations.

## 1. Image Processing

### Android (Improved) ✨
- **Resize**: Yes - max 1920px on longest dimension
- **Compression**: 82% JPEG quality
- **Result**: Camera photos ~450KB

**Code:** [`lib/data/image_store.dart`](file:///Users/z/Documents/Code/Self/timeline/timelineAndroid/lib/data/image_store.dart)
```dart
static const _jpegQuality = 82;
static const _maxDimension = 1920;

// Resizes if too large, then compresses
if (image.width > _maxDimension || image.height > _maxDimension) {
  if (image.width > image.height) {
    image = img.copyResize(image, width: _maxDimension);
  } else {
    image = img.copyResize(image, height: _maxDimension);
  }
}
return img.encodeJpg(image, quality: _jpegQuality);
```

### iOS (Current)
- **Resize**: No
- **Compression**: 82% JPEG quality
- **Result**: Camera photos ~2.4MB

**Code:** `Services/ImageStore.swift`
```swift
guard let data = image.jpegData(compressionQuality: 0.82) else {
    throw ImageStoreError.invalidData
}
```

### Impact
| Image Type | iOS Size | Android Size | Improvement |
|------------|----------|--------------|-------------|
| Screenshot | ~160KB | ~160KB | Same |
| Camera Photo | ~2.4MB | ~450KB | **82% smaller** |

---

## 2. Sync Behavior

### Android (Automatic) ⚡
- **Trigger**: Automatic on create/update/delete
- **Queue**: Notes immediately queued via `syncEngine.queueNoteForSync()`
- **Upload**: Periodic automatic sync (every 30 seconds)
- **User Action**: None required

**Implementation:**
```dart
// In ComposeScreen, EditScreen, DetailScreen, TimelineScreen
await syncEngine.queueNoteForSync(note, 'create');
```

**Periodic Timer:**
```dart
// SyncEngine starts automatic sync every 30 seconds
_syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
  runSync();
});
```

### iOS (Manual) 👆
- **Trigger**: Manual user action required
- **Queue**: Notes queued locally
- **Upload**: Only when user pulls to refresh or taps sync
- **User Action**: Pull-to-refresh or sync button

### Impact
- **Android**: Always up-to-date, better for real-time sync
- **iOS**: User controls when to sync, better for battery/bandwidth control

---

## Summary

| Feature | iOS | Android | Reason for Difference |
|---------|-----|---------|----------------------|
| **Image Resize** | ❌ No | ✅ Yes (1920px max) | Android improvement to reduce upload sizes |
| **Sync Trigger** | 👆 Manual | ⚡ Automatic | Android UX improvement for always-current data |

## Recommendations

1. **Image Resize**: Consider adding resize logic to iOS to match Android's efficiency
2. **Sync Behavior**: Both approaches are valid - Android prioritizes convenience, iOS prioritizes user control
