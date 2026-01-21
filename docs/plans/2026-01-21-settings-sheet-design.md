# Settings Sheet Design

**Goal:** Add a simple Settings sheet with Logout, Full Resync, and Notesync status (last sync/error).

**Context:** The app already has manual sync and auth state via `AuthSessionManager` and `NotesyncUIState`.

## UI Layout

Present a `SettingsView` sheet from a gear icon in the Timeline toolbar.

**Sections (SwiftUI Form):**

1) **Account**
- `Logout` button (visible only when signed in).
- When signed out, show a short “Sign in to manage account” note instead.

2) **Sync**
- `Full Resync` button (visible only when signed in).
- Tapping shows a confirmation alert before enqueuing all local notes for upload.

3) **Status**
- “Last Sync”: formatted `syncState.lastSyncAt` or “Never”.
- “Last Error”: `syncState.lastError` or “None”.

## Behavior

- Logout immediately clears auth state and dismisses the sheet.
- Full Resync enqueues all notes and starts sync, then dismisses the sheet.
- Status is read-only and can be shown even when signed out.

## Error Handling

- If resync fails to enqueue, show an alert and keep the sheet open.
- If sync fails after enqueue, keep queued items for retry.

## Testing

- UI state test: Settings button present in toolbar; Logout/Resync visible only when signed in.
- Status test: “Last Sync/Last Error” strings display fallback values when nil.

## Open Questions

- Should the sheet include app version or backend URL?
