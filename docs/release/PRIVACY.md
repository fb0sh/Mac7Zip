# Privacy

Mac7Zip runs entirely on your Mac.

- **No telemetry, no analytics, no network calls.** The app does not contact any
  server for normal operation.
- Archives and files are read and written locally via the bundled 7-Zip engine.
- Preferences, favourites and the last location are stored locally in
  `UserDefaults`. They never leave the device.
- Passwords are **not** stored. Password-protected archives are refused by default
  because 7-Zip's prompt cannot be answered securely without exposing the secret
  (see ADR-005); Mac7Zip will not silently place passwords in process arguments.
