# Changelog

All notable changes to TypstUniverseKit are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Deployment floor raised to the OS 27 generation: iOS / iPadOS 27+, macOS 27+, visionOS 27+. Requires Swift 6.4+ and Xcode 27+ (`swift-tools-version: 6.4`). No API changes.

## [1.0.0] — 2026-11-20 (Draft for Architecture Review)

### Added

- **Core (`TypstUniverseCore`)** — strict `SemanticVersion`, 19 official `UniverseCategory` values plus forward-compatible custom fallback, extensible `UniverseDiscipline`, `TypstNamespace` / `PackageSpec` / `UniversePackage` / `PackageVersion` / `TypstManifest` models, lenient `IndexDecoder` + `VersionGrouper`, `OfficialUniverseRegistry` with ETag/`If-None-Match`, weighted `UniverseSearchEngine` (facets, five sort orders, curated helpers), and a pure-Swift `TypstTomlParser`.
- **Storage (`TypstUniverseStorage`)** — `SecureTarGzExtractor` (pure-Swift gzip inflate + USTAR reader with tar-slip, symlink/hardlink, device-node, depth, and size guards), `PackageCacheManager` actor (deduplicated downloads, atomic staging installs, footprint APIs, LRU eviction), `TemplateScaffolder` (`typst init` on disk + in-memory, three conflict policies), `LocalNamespaceScanner` (`@local` merge), and the `TypstUniverseClient` headless facade with stale-while-revalidate sync.
- **UI (`TypstUniverseUI`)** — `UniverseBrowserModel` state machine, `ThumbnailPipeline` (memory + disk WebP cache), `TypstUniverseBrowserView`, `TemplatePickerSheet` (browses, downloads, scaffolds, and reports the project), `PackageDetailView`, template cards, category pills, version badges, import-copy button, environment hooks, `TypstUniverseConfiguration`, and a zero-tracking privacy manifest.
- **Tests** — 26 tests: SemVer/decoding/search/TOML suites, adversarial tar + scaffolding suites, browser ViewModel suites.
- **Docs & release engineering** — README quick-start, DocC catalogs, `Examples/UniverseExplorerApp`, CI matrix (macOS + Linux Core), Apache-2.0 license.
