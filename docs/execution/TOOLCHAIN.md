# Toolchain & Reproducibility (TKT-M6-08)

| Tool | Pinned version | Source |
|------|----------------|--------|
| Xcode | 26.6 | `versions.env`, CI asserts installed version |
| XcodeGen | 2.44.1 | `versions.env`, CI installs via Homebrew |
| SwiftLint | 0.57.1 | `versions.env`, non-blocking lint |
| swift-format | 602.0.0 | `versions.env` |
| 7-Zip (`7zz`) | 26.06 | `versions.env`, `Vendor/7zz/26.06` + SHA-256 |

## Reproducible build steps
1. Install Xcode 26.6 (macOS 26 SDK).
2. `brew install xcodegen` (version per `versions.env`).
3. `xcodegen generate`
4. `xcodebuild -scheme Mac7Zip -configuration Release build`

CI (`build.yml`) prints and checks these versions; `7zz` is verified by
`scripts/verify-7zz.sh` against `Vendor/7zz/26.06/SHA256SUMS`.
