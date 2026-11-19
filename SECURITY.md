# Security Policy

TypstUniverseKit downloads and extracts community-authored archives, so archive handling is security-critical code.

## Supported versions

| Version | Supported |
|---|---|
| 1.0.x (current draft) | Yes |

## Reporting a vulnerability

- **Do not open a public issue** for suspected vulnerabilities in archive extraction, path validation, decompression limits, or any sandbox-escape concern.
- Contact the maintainers privately (see the repository's contact links). Include:
  1. A description of the bypass or unsafe behavior,
  2. A minimal proof-of-concept archive or input (as bytes or generation code),
  3. The expected vs. actual behavior.

We aim to acknowledge reports within 3 business days and to ship a fix with regression tests before any public disclosure.

## Security design (summary)

- `SecureTarGzExtractor` rejects absolute paths, `..` components, null bytes, backslashes, drive-letter paths, and over-deep paths; rejects symlinks, hardlinks, device nodes, and FIFOs; and enforces uncompressed-byte and file-count ceilings during streaming extraction.
- `PackageCacheManager` installs atomically (unique staging directory + rename) and only fetches archives over HTTPS.
- See the DocC article “Archive Security” (`Sources/TypstUniverseCore/Documentation.docc/Security.md`) for the full threat model.
