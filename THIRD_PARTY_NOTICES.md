# Third-Party Notices

Mac7Zip bundles the **7-Zip** command-line engine (`7zz`).

| Component | Version | License | Notes |
|-----------|---------|---------|-------|
| 7-Zip (`7zz`) | 26.06 | LGPL v2.1+ with unRAR restriction | © Igor Pavlov and contributors |

- Full license texts are bundled in the app (`7zz-LICENSE.txt`, `7zz-README.txt`)
  and reproduced in `Support/NOTICE.md`.
- **unRAR restriction:** the RAR code may not be used to build a RAR-compatible
  archiver. Mac7Zip therefore only **extracts** RAR; it never creates RAR files.
- Trademarks: 7-Zip is a trademark of Igor Pavlov. Mac7Zip is not affiliated with
  or endorsed by the 7-Zip project.

## libarchive
- License: BSD-2-Clause
- Copyright: The libarchive project contributors
- Used for: reading archive contents (zip, 7z, rar, tar, gz, bz2, xz, cab, iso, …) in the
  app and the Quick Look preview/thumbnail extensions. Source fetched at build time by
  `scripts/fetch-libarchive.sh`; license text: https://github.com/libarchive/libarchive/blob/master/COPYING
