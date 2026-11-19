# Architecture

How the three modules fit together and where each responsibility lives.

## Layers

- **Core** knows nothing about the network cache or the filesystem beyond parsing: models, registry protocol + official client, version grouping, search, TOML. It is the only module that builds on Linux.
- **Storage** owns side effects: downloading, secure extraction, atomic installs, eviction, scaffolding, `@local` scanning. Shared mutable state (in-flight downloads, disk index) is actor-isolated.
- **UI** owns presentation: an observable state machine, a thumbnail pipeline, and views. It never talks to the network directly except through thumbnails and the client you hand it.

## Data flow

```
index.json → IndexDecoder → [UniversePackage] → UniverseSearchEngine → views
tar.gz → gunzip → SecureTarGzExtractor → staging dir → {ns}/{name}/{ver}/
{ns}/{name}/{ver}/ + typst.toml → TemplateScaffolder → destination/
```

## Forward compatibility

Upstream adds categories and disciplines over time. `UniverseCategory` and `UniverseDiscipline` are extensible structs (not enums), and `PackageVersion` decoding supplies defaults for missing keys and `nil` for malformed dates — so a schema evolution degrades to fewer facets, never a failed catalog load.
