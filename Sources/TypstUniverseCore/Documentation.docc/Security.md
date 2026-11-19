# Archive Security

Threat model and guarantees for extracting community-authored `.tar.gz` archives.

## What we defend against

| Threat | Guard |
|---|---|
| Tar-slip / path traversal (`../../etc/passwd`, absolute paths, null bytes) | Reject entry; no canonical-path escape possible |
| Symlink / hardlink / device-node / FIFO escape | Reject entry outright |
| Decompression bombs | 100 MB uncompressed + 5,000-file + depth-32 ceilings during streaming extraction |
| Corrupted installs from interrupted downloads | Unique staging directory + atomic rename |
| Downgrade / injection | HTTPS-only archive URLs |

## What we do not do

The extractor never follows links, never creates anything but regular files and directories, and never writes outside the staging directory. Limits are configurable via `ExtractionLimits` for hosts that need tighter budgets.

## Reporting

See `SECURITY.md`. Suspected bypasses should be reported privately with a minimal proof-of-concept archive — never as a public issue.
