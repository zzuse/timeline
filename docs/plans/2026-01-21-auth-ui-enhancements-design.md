# Auth UI Enhancements Design

**Goal:** Show a brief success state on login before the login sheet dismisses.

**Context:** The app uses `AuthSessionManager` for sign-in state and `LoginView` for external browser login + callback. Sync is gated by `authSession.isSignedIn`. Images are stored on disk (JPEG under Documents/Images) and SwiftData stores paths, so auth UI changes do not affect storage.

## UX Behavior

- On successful login, the login sheet shows a short success message (e.g., “Signed in successfully”) for ~1–1.5s, then auto-dismisses.
- If login fails, the sheet remains open and shows the existing error state (no auto-dismiss).
- Sync stays disabled while signed out.

## Data Flow and State

- `AuthSessionManager` exposes a transient “login succeeded” flag, e.g. `@Published var didSignInSuccessfully`.
- `LoginView` observes `didSignInSuccessfully` and shows a success message when true.
- The login sheet is dismissed by the host (`TimelineView`) after a short delay once success is observed, keeping navigation centralized.

## Error Handling

- If token exchange fails, `isSignedIn` remains false and `didSignInSuccessfully` stays false.

## Testing

- Add a unit test for `handleCallback` to verify success flag sets on successful exchange.
- UI behavior can be smoke-tested by logging in and confirming the success message appears and the sheet dismisses.

## Open Questions

- Should the success message live in the login sheet only, or also as a brief toast on Timeline?
