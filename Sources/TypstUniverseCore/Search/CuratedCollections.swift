import Foundation

/// Curated collections (FR-2.3): static presets + optional remote feed.
public struct CuratedCollection: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var title: String
    public var packageNames: [String]
    public init(id: String, title: String, packageNames: [String]) {
        self.id = id; self.title = title; self.packageNames = packageNames
    }

    public static let presets: [CuratedCollection] = [
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
