# Full Resync Design

**Goal:** Provide a manual “Full Resync” action that queues all local notes for upload so the server can be rebuilt after data loss.

**Context:** The app is local-first with a file-based sync queue and manual sync. Full resync should not remove existing queue items and must be gated behind authentication.

## UX Behavior

- Add a Settings/Account sheet entry: “Full Resync”.
- Visible only when signed in.
- Tapping shows a confirmation alert (“This will queue all local notes for upload.”).
- After confirmation, enqueue all local notes and start sync.
- Show progress using the existing sync state. If uploads take time, keep UI responsive.

## Data Flow

- Enumerate all local notes from SwiftData.
- For each note, enqueue an update operation with current fields and media paths.
- Append to the existing sync queue; do not clear prior pending operations.
- Use the existing batching logic (10 MB limit) for uploads.
- Server uses LWW to apply incoming state.

## Error Handling

- If enqueuing fails, show “Resync failed” and keep queue intact.
- If upload fails, keep queued items for retry.
- Missing media files: skip those media items, continue with note, show a warning count.

## Testing

- Repository test: full resync enqueues one update per local note.
- Queue test: existing pending items remain after resync enqueue.
- UI state test: resync action visible only when signed in.

## Open Questions

- Does Settings/Account sheet already exist, or should it be introduced?
- Should we log resync activity for diagnostics?
