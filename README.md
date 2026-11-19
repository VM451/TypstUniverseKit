# TypstUniverseKit

Native, modular, zero-dependency Swift Package for the [Typst Universe](https://packages.typst.org) (`packages.typst.org`).

- `TypstUniverseCore` — pure Swift + Foundation (macOS/iOS/visionOS/Linux): models, `OfficialUniverseRegistry` (ETag), `IndexDecoder`/`VersionGrouper`, `UniverseSearchEngine`, `TypstTomlParser`, curated collections.
- `TypstUniverseStorage` — `PackageCacheManager` (deduplicated downloads, atomic installs, LRU cap), `SecureTarGzExtractor` (tar-slip/symlink/bomb guards, pure-Swift gzip+tar), `TemplateScaffolder` (`typst init`, disk + in-memory), `LocalNamespaceScanner` (`@local`), `TypstUniverseClient` facade.
- `TypstUniverseUI` — `UniverseBrowserModel`, `ThumbnailPipeline` (memory+disk WebP), `TypstUniverseBrowserView`, `TemplatePickerSheet`, `PackageDetailView`, `TemplateCardView`, pills/badges, environment hooks, `TypstLivePreviewProviding`.

## 15-line picker

```swift
import SwiftUI
import TypstUniverseStorage
import TypstUniverseUI

struct NewDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        TemplatePickerSheet(client: .shared, initialCategory: .cv) { spec in
            FileManager.default.temporaryDirectory.appending(path: "\(spec.name)-\(UUID().uuidString)")
        } onScaffolded: { _ in dismiss() }
    }
}
```

Headless:

```swift
let universe = TypstUniverseClient.live(configuration: .init(storageDirectory: url))
let catalog = try await universe.syncCatalog()
let results = await universe.search(UniverseQuery(text: "thesis", kind: .templatesOnly))
let spec = PackageSpec(namespace: .preview, name: "basic-resume", version: SemanticVersion(0, 2, 8))
let project = try await universe.scaffoldTemplate(spec, to: dest)
```

Build with Xcode toolchain (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build`); `swift test` for Core+Storage. See `Examples/UniverseExplorerApp`.
