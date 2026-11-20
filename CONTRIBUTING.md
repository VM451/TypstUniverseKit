# Contributing to TypstUniverseKit

Thanks for helping! This guide keeps contributions fast to review and safe to ship.

## Toolchain

- **Xcode 26+ is required** for `TypstUniverseUI` and the full test suite — the SwiftUI and Swift Testing macros need Xcode's plugin toolchain. The Command-Line Tools toolchain alone cannot compile `@State`, `@Bindable`, or `@Test` macros.
- Build and test with the Xcode toolchain:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

- `TypstUniverseCore` also builds on Linux (`swift build --target TypstUniverseCore`); keep it Foundation-only.

## Style rules

- **Swift 6, zero warnings.** The package builds with `-strict-concurrency=complete`. All public models are `Sendable` value types; shared mutable state lives in actors; UI state is `@Observable` on `@MainActor`.
- **No `print()` in library code.** Use `KitLog` (`Logger(subsystem: "dev.typstuniversekit", category: …)`).
- **No third-party runtime dependencies.** Foundation, URLSession, ImageIO, and the in-house gzip/TAR/TOML readers only. The Swift-DocC plugin is the sole exception, and it is build tooling only. Propose any other exception in an issue first.
- **Security-first for archives.** Any change to `SecureTarGzExtractor` must keep the tar-slip, symlink/hardlink, device-node, depth, and size guards, and add a regression test in `Tests/TypstUniverseStorageTests/StorageTests.swift`.
- **Accessibility is a feature.** New views need VoiceOver labels/hints, Dynamic Type-safe layout (test an Accessibility size), and Reduced Motion / Increased Contrast behavior where animation or color carries meaning.

## Tests

- Add or update tests with every behavior change:
  - Core → `Tests/TypstUniverseCoreTests/CoreTests.swift` (Swift Testing `@Suite`/`@Test`).
  - Storage/security → `Tests/TypstUniverseStorageTests/StorageTests.swift`.
  - UI → `Tests/TypstUniverseUITests/` (`XCTestCase`, so the suite also compiles under the CLT toolchain).
- Run the full suite before opening a PR.

## Commits & PRs

- We ship to `main` as fine-grained atomic Conventional Commits (`feat(core-search): …`, `fix(storage-cache): …`, `test(ui): …`, `docs(readme): …`). One logical unit per commit, imperative subject ≤ 72 chars.
- Keep PRs focused; include what changed, why, and the verification output (`swift build`, `swift test`).

## Docs

- Public API needs `///` DocC comments. User-facing behavior belongs in the README plus the relevant `Documentation.docc` article, not only in code comments.
