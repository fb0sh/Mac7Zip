# 7-Zip 26.06 (bundled helper)

This directory vendors the official **7-Zip 26.06** macOS console binary (`7zz`)
used as Mac7Zip's archive engine. See ADR-009.

## Upstream

- Project: 7-Zip by Igor Pavlov — <https://7-zip.org/>
- Release: `ip7z/7zip` tag **26.06** — <https://github.com/ip7z/7zip/releases/tag/26.06>
- Fetched from the official release assets (not re-hosted from third parties).

## Pinned assets

| Asset | Architecture | Archive SHA-256 |
|---|---|---|
| `7z2606-mac.tar.xz` | arm64 (Mach-O) | `b6f17920b4240940461dac8ef4009891881ac44d2a5ead625ede2ec8472185dd` |
| `7z2606-mac-x64.tar.xz` | x86_64 (Mach-O) | `3af68b124052da7fc2a246c96b0bea6a68bfee389baa788f4cead1a133445586` |

## Extracted binaries (committed)

`SHA256SUMS` pins the extracted executables:

```
56cf8eb2fdc6f9c0ac5d7a3cd238505814ac8ed6b88a7c64a7e3256036252c60  arm64/7zz
d54aa0864244abeef158772fbde3dd9bac2b93a54c564a76c4334c5a8bcaf35a  x86_64/7zz
```

CI verifies these hashes before bundling (`scripts/verify-7zz.sh`). A mismatch fails the build.

## License

7-Zip is licensed under the **GNU LGPL** (some files LGPL + **unRAR restriction**, some BSD).
See `License.txt` (verbatim from the official archive) and `readme.txt`.

Redistribution obligations: binary redistribution must reproduce the license
information; the LGPL requires source availability for the LGPL-covered code.
We redistribute the **unmodified** official binary and link to upstream source.

**unRAR restriction:** RAR archives may be *read/extracted*, but the RAR
compression algorithm may not be re-created. Mac7Zip therefore **never creates
RAR archives** and has a test asserting that RAR creation is refused.

## Bundling

`scripts/bundle-7zz.sh` copies the correct architecture's binary to
`Mac7Zip.app/Contents/Helpers/7zz` and the license to `Contents/Resources/`.

## Updating

1. Download the new official assets; verify SHA-256 against the release page.
2. Extract `7zz` for each architecture; record new hashes in `SHA256SUMS`.
3. Update ADR-009 and this file.
4. Run the full CI suite (including `TKT-M2-11` archive integration tests).
