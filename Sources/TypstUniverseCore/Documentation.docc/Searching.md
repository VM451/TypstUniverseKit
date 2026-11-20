# Searching and Filtering

The query model, ranking, and storefront helpers.

## UniverseQuery

One value describes the whole request: free text, kind (all / templates-only / libraries-only), category set with AND/OR semantics, discipline set, compiler compatibility ceiling, namespace set, and sort order.

```swift
UniverseQuery(
    text: "plot",
    kind: .packagesOnly,
    disciplines: [.physics],
    compatibleWithCompiler: SemanticVersion(0, 14, 0),
    sort: .relevance
)
```

Facets intersect: a package must pass *every* active filter, and every text token must match *something* (name, keyword, description, or author).

## Ranking

Exact package-name matches outrank prefixes, which outrank keyword hits, then description and author mentions. With empty text, `.relevance` falls back to recency so the default view is a sensible storefront.

## Storefront helpers

- `newAndRecentlyUpdated(_:withinDays:now:)` — created or updated within the window (default 30 days), newest first.
- `categoryCounts(_:)` — live per-category counts for sidebar badges.
- `CuratedCollection.presets` — Official Templates plus Resumes, Presentations, Academic Papers, Visualizations; `packages(in:)` resolves them against any catalog.
- `CuratedCollection.officialTemplates` — the eight templates directly maintained by the Typst team ([typst/templates](https://github.com/typst/templates)), published as `@preview` packages. They need no special handling: catalog sync, download, and scaffolding all work through the normal paths, and `UniversePackage.isOfficialTemplate` flags them for UI badges.
