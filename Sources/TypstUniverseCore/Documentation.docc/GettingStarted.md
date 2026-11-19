# Getting Started

Add Typst Universe to your app in three steps: sync the catalog, search it locally, and scaffold a template.

## Sync the catalog

```swift
import TypstUniverseCore
import TypstUniverseStorage

let universe = TypstUniverseClient.shared
let catalog = try await universe.syncCatalog()
```

The first call returns the on-disk cache immediately when present, then revalidates with the registry via `ETag` / `If-None-Match` — so the app works in Airplane Mode and online refreshes cost ~1 KB on a `304 Not Modified`.

## Search locally

```swift
let results = await universe.search(UniverseQuery(
    text: "thesis",
    kind: .templatesOnly,
    categories: [.thesis, .paper],
    sort: .recentlyUpdated
))
```

Search is synchronous, allocation-light value-type filtering that stays off the `MainActor`. Rank order is exact-name → name-prefix → keywords → description → authors, and every token must match (AND).

## Scaffold a template

```swift
let spec = PackageSpec(namespace: .preview, name: "basic-resume", version: SemanticVersion(0, 2, 8))
let project = try await universe.scaffoldTemplate(spec, to: newDocumentFolderURL)
print(project.entrypointURL) // e.g. …/main.typ
```

`conflictPolicy` defaults to `.failIfNonEmpty`, matching the Typst CLI. Use `.createSubdirectory(named:)` or `.overwrite` for app-managed folders, or `scaffoldInMemory(_:)` for `FileWrapper` / SwiftData hosts.
