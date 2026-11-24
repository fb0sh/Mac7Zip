# M5 Acceptance Checklist (SPEC-MI)

Automated evidence runs in CI on `macos-26`; items marked **manual** must be
confirmed on a real macOS 26 desktop before release.

| AC | Requirement | Automated | Manual |
|----|-------------|-----------|--------|
| AC-MI-1 | Double-click a declared archive type opens & browses it | plist config test (`BundleConfigTests.testProjectDeclaresDocumentTypes`) | Finder double-click / Open With |
| AC-MI-2 | Quick Look previews an archive entry, temp cleaned up | `QuickLookTempWorkspace` cleanup test | Actual QL panel + file inspection |
| AC-MI-3 | Settings persistence + activation default affects operations | `AppSettingsTests`, `SettingsStore` persistence | Settings UI interaction |
| AC-MI-4 | Completion notification respects toggle + permission | `NotificationCoordinatorTests` (fake) | Real banner delivery |
| AC-MI-5 | Licenses/notices present and readable | `BundleConfigTests.testNoticeFileExists` + About view | Visual read of About |
| AC-MI-6 | Finder Service actions route correctly | `ServiceActionPlannerTests` | Service invocation from Finder |

## Sign-off
- [ ] Automated suite green on `macos-26`.
- [ ] Every **manual** row above verified on macOS 26.
- [ ] Linked to `docs/execution/MANUAL-CHECKS.md`.
