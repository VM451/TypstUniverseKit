import Foundation

/// Curated collections (FR-2.3): static presets + optional remote feed.
public struct CuratedCollection: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var title: String
    public var packageNames: [String]
    public init(id: String, title: String, packageNames: [String]) {
        self.id = id; self.title = title; self.packageNames = packageNames
    }

    /// Slugs of the templates directly maintained by the Typst team
    /// (https://github.com/typst/templates). Verified 2026-11-20: every one
    /// is published to the Universe as an `@preview` package, so entries
    /// already flow through the normal catalog sync — this list only gives
    /// them a storefront home. Keep namespace-gated: a same-named `@local`
    /// package must never read as official.
    public static let officialTemplateNames: [String] = [
        "appreciated-letter",
        "badformer",
        "cereal-words",
        "charged-ieee",
        "dashing-dept-news",
        "icicle",
        "unequivocal-ams",
        "wonderous-book"
    ]

    /// The Typst team's own templates, featured first.
    public static let officialTemplates = CuratedCollection(
        id: "official-templates",
        title: "Official Templates",
        packageNames: officialTemplateNames
    )

    public static let presets: [CuratedCollection] = [
        officialTemplates,
        CuratedCollection(id: "resumes", title: "Resumes & CVs", packageNames: ["basic-resume", "modern-cv", "resume"]),
        CuratedCollection(id: "presentations", title: "Presentations", packageNames: ["polylux", "touying", "diapo"]),
        CuratedCollection(id: "papers", title: "Academic Papers", packageNames: ["ieee", "acm", "springer"]),
        CuratedCollection(id: "visualizations", title: "Visualizations", packageNames: ["cetz", "fletcher", "plot"])
    ]

    public func packages(in catalog: [UniversePackage]) -> [UniversePackage] {
        let byName = Dictionary(uniqueKeysWithValues: catalog.map { ($0.name, $0) })
        return packageNames.compactMap { byName[$0] }
    }
}
