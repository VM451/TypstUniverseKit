import Foundation

public enum PackageKindFilter: Sendable, Hashable, Codable {
    case all
    case templatesOnly
    case packagesOnly
}

public enum SortOrder: Sendable, Hashable, Codable {
    case relevance
    case recentlyUpdated
    case newlyReleased
    case alphabeticalAscending
    case alphabeticalDescending
}

/// Declarative local search query (FR-2).
public struct UniverseQuery: Sendable, Hashable, Codable {
    public var text: String
    public var kind: PackageKindFilter
    public var categories: Set<UniverseCategory>
    public var disciplines: Set<UniverseDiscipline>
    public var compatibleWithCompiler: SemanticVersion?
    public var namespaces: Set<TypstNamespace>?
    public var sort: SortOrder
    public var matchAllCategories: Bool

    public init(
        text: String = "",
        kind: PackageKindFilter = .all,
        categories: Set<UniverseCategory> = [],
        disciplines: Set<UniverseDiscipline> = [],
        compatibleWithCompiler: SemanticVersion? = nil,
        namespaces: Set<TypstNamespace>? = nil,
        sort: SortOrder = .relevance,
        matchAllCategories: Bool = false
    ) {
        self.text = text
        self.kind = kind
        self.categories = categories
        self.disciplines = disciplines
        self.compatibleWithCompiler = compatibleWithCompiler
        self.namespaces = namespaces
        self.sort = sort
        self.matchAllCategories = matchAllCategories
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
            && categories.isEmpty && disciplines.isEmpty
            && compatibleWithCompiler == nil && namespaces == nil
            && kind == .all
    }
}

/// Weighted full-text + faceted local search engine.
/// Runs on any actor; no shared mutable state.
public struct UniverseSearchEngine: Sendable {
    public init() {}

    public func search(_ packages: [UniversePackage], query: UniverseQuery) -> [UniversePackage] {
        var scored: [(pkg: UniversePackage, score: Double)] = []
        scored.reserveCapacity(packages.count)
        for pkg in packages {
            guard Self.passesFacets(pkg, query: query) else { continue }
            let score = Self.score(pkg, text: query.text)
            if !query.text.trimmingCharacters(in: .whitespaces).isEmpty, score <= 0 { continue }
            scored.append((pkg, score))
        }
        switch query.sort {
        case .relevance:
            // When no text, relevance == recently updated.
            if query.text.trimmingCharacters(in: .whitespaces).isEmpty {
                scored.sort { ($0.pkg.lastUpdatedAt ?? .distantPast) > ($1.pkg.lastUpdatedAt ?? .distantPast) }
            } else {
                scored.sort { $0.score > $1.score }
            }
        case .recentlyUpdated:
            scored.sort { ($0.pkg.lastUpdatedAt ?? .distantPast) > ($1.pkg.lastUpdatedAt ?? .distantPast) }
        case .newlyReleased:
            scored.sort { ($0.pkg.firstReleasedAt ?? .distantPast) > ($1.pkg.firstReleasedAt ?? .distantPast) }
        case .alphabeticalAscending:
            scored.sort { $0.pkg.name.localizedCaseInsensitiveCompare($1.pkg.name) == .orderedAscending }
        case .alphabeticalDescending:
            scored.sort { $0.pkg.name.localizedCaseInsensitiveCompare($1.pkg.name) == .orderedDescending }
        }
        return scored.map(\.pkg)
    }

    /// Per-category counts over a package list (for sidebar badges).
    public func categoryCounts(_ packages: [UniversePackage]) -> [UniverseCategory: Int] {
        var counts: [UniverseCategory: Int] = [:]
        for pkg in packages {
            guard let latest = pkg.latestVersion else { continue }
            for c in Set(latest.categories) { counts[c, default: 0] += 1 }
        }
        return counts
    }

    /// Packages created/updated within `days` of `now`.
    public func newAndRecentlyUpdated(_ packages: [UniversePackage], withinDays days: Int = 30, now: Date = Date()) -> [UniversePackage] {
        let cutoff = now.addingTimeInterval(TimeInterval(-days * 24 * 3600))
        return packages.filter { pkg in
            if let r = pkg.firstReleasedAt, r >= cutoff { return true }
            if let u = pkg.lastUpdatedAt, u >= cutoff { return true }
            return false
        }.sorted { ($0.lastUpdatedAt ?? .distantPast) > ($1.lastUpdatedAt ?? .distantPast) }
    }

    // MARK: - Facets

    static func passesFacets(_ pkg: UniversePackage, query: UniverseQuery) -> Bool {
        guard let latest = pkg.latestVersion else { return false }
        switch query.kind {
        case .all: break
        case .templatesOnly: guard pkg.isTemplate else { return false }
        case .packagesOnly: guard !pkg.isTemplate else { return false }
        }
        if let ns = query.namespaces, !ns.contains(pkg.namespace) { return false }
        if !query.categories.isEmpty {
            let set = Set(latest.categories)
            if query.matchAllCategories {
                guard query.categories.isSubset(of: set) else { return false }
            } else {
                guard !set.isDisjoint(with: query.categories) else { return false }
            }
        }
        if !query.disciplines.isEmpty {
            guard !Set(latest.disciplines).isDisjoint(with: query.disciplines) else { return false }
        }
        if let target = query.compatibleWithCompiler {
            // Package requires compiler <= target.
            if let need = latest.compilerVersion, need > target { return false }
        }
        return true
    }

    // MARK: - Scoring

    static func score(_ pkg: UniversePackage, text: String) -> Double {
        let q = text.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return 1 }
        guard let latest = pkg.latestVersion else { return 0 }
        let tokens = q.split(separator: " ").map { normalize(String($0)) }.filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return 1 }
        let name = normalize(pkg.name)
        let keywords = latest.keywords.map(normalize)
        let desc = normalize(latest.description)
        let authors = latest.authors.map { normalize($0.name) }
        var total = 0.0
        for tok in tokens {
            var s = 0.0
            if name == tok { s += 100 }
            else if name.hasPrefix(tok) { s += 60 }
            else if name.contains(tok) { s += 30 }
            if keywords.contains(tok) { s += 25 }
            else if keywords.contains(where: { $0.hasPrefix(tok) }) { s += 12 }
            if desc.contains(tok) { s += 5 }
            if authors.contains(where: { $0.contains(tok) }) { s += 8 }
            if s == 0 { return 0 } // every token must match something (AND)
            total += s
        }
        return total
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
    }
}
