# Restore Latest Notes (Empty-State) Design

**Goal:** When the local notes list is empty, show a one-time “Restore latest 10” action that fetches the most recent notes from the server and inserts them locally after login.

**Context:** The app is local-first with SwiftData. Sync is manual and authenticated. This restore feature is only for the empty-state after reinstall; once any note exists locally, the restore action disappears.

## UX Behavior

- When `notes.isEmpty == true`, show an empty-state action: “Restore latest 10”.
- The action is only visible when signed in; otherwise show “Sign In to Restore”.
- Once any note exists (restored or newly created), the action is no longer shown.
- On success, show a brief “Restored 10 notes” message and display the notes list.
- On failure, keep the empty-state and show an error alert.

## Data Flow

- Add a new client call (e.g., `GET /api/notes?limit=10` or `POST /api/notesync/pull` with `limit=10`) that returns the latest notes and media.
- Use existing auth headers and base URL config.
- Upsert notes by `id` into SwiftData to avoid duplicates.
- For media, avoid re-downloading if a matching `checksum` already exists locally.
- If media download fails, still insert the note and report partial failures.

## Error Handling

- 401/expired token: prompt re-login.
- Network error: show generic failure and keep empty-state.
- Partial media failures: surface a warning count, but do not block notes.

## Testing

- UI state test: restore action appears only when notes list is empty and user is signed in.
- Repository test: restore upserts notes by `id` without duplicates.
- Client test: restore request uses correct endpoint and headers.

## Open Questions

- Exact backend endpoint and response shape for “latest 10” (notes + media).
- Whether media should be returned inline (base64) or via URLs.
