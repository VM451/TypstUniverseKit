# Changelog

All notable changes to TypstUniverseKit are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- CI now pins Swift 6.2 via `swift-actions/setup-swift` on every job (matching `swift-tools-version: 6.2`) and declares the Swift-DocC plugin so the docs job's `generate-documentation` command exists.

### Removed

- Linux as a supported platform: the `core-linux` CI job is gone, along with Linux mentions in the README and DocC catalog. Apple platforms only (iOS / macOS / visionOS 26+).

### Changed

- Deployment floor is the OS 26 generation: iOS / iPadOS 26+, macOS 26+, visionOS 26+. Requires Swift 6.2+ and Xcode 26+ (`swift-tools-version: 6.2`). OS 27 follows as soon as a public Swift/Xcode toolchain ships it — today only future/beta toolchains know `.v27`, and CI must stay green on what GitHub runners can actually install. No API changes.

### Added

- Official Typst team templates ([typst/templates](https://github.com/typst/templates)) as a first-class storefront: `CuratedCollection.officialTemplates` preset (featured first in `presets`), `UniversePackage.isOfficialTemplate` provenance helper, and an "Official" badge on `TemplateCardView`. No new networking or vendored files — all eight are `@preview` Universe packages, so sync, download, and scaffolding reuse the existing paths.

## [1.0.0] — 2026-11-20 (Draft for Architecture Review)

### Added

- **Core (`TypstUniverseCore`)** — strict `SemanticVersion`, 19 official `UniverseCategory` values plus forward-compatible custom fallback, extensible `UniverseDiscipline`, `TypstNamespace` / `PackageSpec` / `UniversePackage` / `PackageVersion` / `TypstManifest` models, lenient `IndexDecoder` + `VersionGrouper`, `OfficialUniverseRegistry` with ETag/`If-None-Match`, weighted `UniverseSearchEngine` (facets, five sort orders, curated helpers), and a pure-Swift `TypstTomlParser`.
- **Storage (`TypstUniverseStorage`)** — `SecureTarGzExtractor` (pure-Swift gzip inflate + USTAR reader with tar-slip, symlink/hardlink, device-node, depth, and size guards), `PackageCacheManager` actor (deduplicated downloads, atomic staging installs, footprint APIs, LRU eviction), `TemplateScaffolder` (`typst init` on disk + in-memory, three conflict policies), `LocalNamespaceScanner` (`@local` merge), and the `TypstUniverseClient` headless facade with stale-while-revalidate sync.
- **UI (`TypstUniverseUI`)** — `UniverseBrowserModel` state machine, `ThumbnailPipeline` (memory + disk WebP cache), `TypstUniverseBrowserView`, `TemplatePickerSheet` (browses, downloads, scaffolds, and reports the project), `PackageDetailView`, template cards, category pills, version badges, import-copy button, environment hooks, `TypstUniverseConfiguration`, and a zero-tracking privacy manifest.
- **Tests** — 26 tests: SemVer/decoding/search/TOML suites, adversarial tar + scaffolding suites, browser ViewModel suites.
- **Docs & release engineering** — README quick-start, DocC catalogs, `Examples/UniverseExplorerApp`, CI matrix (macOS + Linux Core), Apache-2.0 license.
