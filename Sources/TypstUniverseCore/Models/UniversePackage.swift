import Foundation

/// Parsed author entry: display name plus optional handle / URL / email.
public struct PackageAuthor: Sendable, Hashable, Codable, CustomStringConvertible {
    public var name: String
    public var handle: String?
    public var url: String?
    public var email: String?

    public init(name: String, handle: String? = nil, url: String? = nil, email: String? = nil) {
        self.name = name
        self.handle = handle
        self.url = url
        self.email = email
    }

    /// Lenient parsing: index.json authors may be plain strings
    /// (`"John Doe <john@example.com>"`) or structured objects.
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = Self.parse(s)
            return
        }
        let kc = try decoder.container(keyedBy: CodingKeys.self)
        let name = (try? kc.decode(String.self, forKey: .name)) ?? ""
        self.init(
            name: name,
            handle: try? kc.decodeIfPresent(String.self, forKey: .handle),
            url: try? kc.decodeIfPresent(String.self, forKey: .url),
            email: try? kc.decodeIfPresent(String.self, forKey: .email)
        )
    }

    private static func parse(_ s: String) -> PackageAuthor {
        var name = s
        var email: String?
        var handle: String?
        // Extract <email>.
        if let l = s.firstIndex(of: "<"), let r = s.firstIndex(of: ">"), l < r {
            email = String(s[s.index(after: l)..<r]).trimmingCharacters(in: .whitespaces)
            name = String(s[..<l]).trimmingCharacters(in: .whitespaces)
        }
        // Extract @handle suffix.
        if let at = name.lastIndex(of: "@") {
            let candidate = String(name[name.index(after: at)...]).trimmingCharacters(in: .whitespaces)
            if !candidate.isEmpty, !candidate.contains(" ") {
                handle = candidate
                name = String(name[..<at]).trimmingCharacters(in: .whitespaces)
            }
        }
        // Extract (url).
        if let l = name.firstIndex(of: "("), let r = name.firstIndex(of: ")"), l < r {
            let url = String(name[name.index(after: l)..<r])
            name = String(name[..<l]).trimmingCharacters(in: .whitespaces)
            return PackageAuthor(name: name.isEmpty ? s : name, handle: handle, url: url, email: email)
        }
        return PackageAuthor(name: name.isEmpty ? s : name, handle: handle, url: nil, email: email)
    }

    public var description: String { name }

    private enum CodingKeys: String, CodingKey { case name, handle, url, email }
}

/// One release entry as it appears in `index.json` (flat array, one element
/// per package version).
public struct PackageVersion: Sendable, Hashable, Codable {
    public var name: String
    public var version: SemanticVersion
    public var namespace: TypstNamespace
    public var description: String
    public var authors: [PackageAuthor]
    public var license: String?
    public var repository: URL?
    public var homepage: URL?
    public var keywords: [String]
    public var categories: [UniverseCategory]
    public var disciplines: [UniverseDiscipline]
    public var compilerVersion: SemanticVersion?
    public var updatedAt: Date?
    public var releasedAt: Date?
    public var archiveSize: Int?
    public var template: TemplateInfo?

    public var spec: PackageSpec { PackageSpec(namespace: namespace, name: name, version: version) }
    public var isTemplate: Bool { template != nil }

    public init(
        name: String, version: SemanticVersion, namespace: TypstNamespace = .preview,
        description: String = "", authors: [PackageAuthor] = [],
        license: String? = nil, repository: URL? = nil, homepage: URL? = nil,
        keywords: [String] = [], categories: [UniverseCategory] = [],
        disciplines: [UniverseDiscipline] = [], compilerVersion: SemanticVersion? = nil,
        updatedAt: Date? = nil, releasedAt: Date? = nil, archiveSize: Int? = nil,
        template: TemplateInfo? = nil
    ) {
        self.name = name
        self.version = version
        self.namespace = namespace
        self.description = description
        self.authors = authors
        self.license = license
        self.repository = repository
        self.homepage = homepage
        self.keywords = keywords
        self.categories = categories
        self.disciplines = disciplines
        self.compilerVersion = compilerVersion
        self.updatedAt = updatedAt
        self.releasedAt = releasedAt
        self.archiveSize = archiveSize
        self.template = template
    }

    private enum CodingKeys: String, CodingKey {
        case name, version, namespace, description, authors, license, repository, homepage
        case keywords, categories, disciplines, template
        case compilerVersion = "compiler"
        case updatedAt = "updated_at"
        case releasedAt = "released_at"
        case archiveSize = "size"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        // Version may be a semver string or already validated.
        if let v = try? c.decode(SemanticVersion.self, forKey: .version) {
            version = v
        } else if let s = try? c.decode(String.self, forKey: .version), let v = SemanticVersion(s) {
            version = v
        } else {
            version = SemanticVersion(0, 0, 0)
        }
        namespace = (try? c.decode(TypstNamespace.self, forKey: .namespace)) ?? .preview
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        authors = (try? c.decode([PackageAuthor].self, forKey: .authors)) ?? []
        license = try? c.decodeIfPresent(String.self, forKey: .license)
        repository = Self.lenientURL(try? c.decodeIfPresent(String.self, forKey: .repository))
        homepage = Self.lenientURL(try? c.decodeIfPresent(String.self, forKey: .homepage))
        keywords = (try? c.decode([String].self, forKey: .keywords)) ?? []
        categories = (try? c.decode([UniverseCategory].self, forKey: .categories)) ?? []
        disciplines = (try? c.decode([UniverseDiscipline].self, forKey: .disciplines)) ?? []
        if let s = try? c.decodeIfPresent(String.self, forKey: .compilerVersion) {
            compilerVersion = SemanticVersion(s)
        } else {
            compilerVersion = try? c.decodeIfPresent(SemanticVersion.self, forKey: .compilerVersion)
        }
        updatedAt = Self.lenientDate(c, key: .updatedAt)
        releasedAt = Self.lenientDate(c, key: .releasedAt)
        archiveSize = (try? c.decodeIfPresent(Int.self, forKey: .archiveSize)) ?? nil
        template = try? c.decodeIfPresent(TemplateInfo.self, forKey: .template)
    }

    private static func lenientURL(_ s: String?) -> URL? {
        guard let s, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private static func lenientDate(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        if let d = try? c.decodeIfPresent(Date.self, forKey: key) { return d }
        if let ms = try? c.decodeIfPresent(Double.self, forKey: key) {
            // Heuristic: seconds vs milliseconds since epoch.
            return Date(timeIntervalSince1970: ms > 1e12 ? ms / 1000 : ms)
        }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: s) { return d }
            let iso2 = ISO8601DateFormatter()
            if let d = iso2.date(from: s) { return d }
        }
        return nil
    }
}

/// `[template]` table: entrypoint + thumbnail info for template packages.
public struct TemplateInfo: Sendable, Hashable, Codable {
    public var path: String
    public var entrypoint: String
    public var thumbnail: String?

    public init(path: String, entrypoint: String, thumbnail: String? = nil) {
        self.path = path
        self.entrypoint = entrypoint
        self.thumbnail = thumbnail
    }
}

/// All releases of one `(namespace, name)` package, sorted by semver.
public struct UniversePackage: Sendable, Hashable, Codable, Identifiable {
    public var namespace: TypstNamespace
    public var name: String
    /// Newest-first by semver.
    public var versions: [PackageVersion]

    public init(namespace: TypstNamespace, name: String, versions: [PackageVersion]) {
        self.namespace = namespace
        self.name = name
        self.versions = versions.sorted { $0.version > $1.version }
    }

    public var id: String { "\(namespace.rawValue)/\(name)" }
    public var latestVersion: PackageVersion? { versions.first }
    public var latest: SemanticVersion? { latestVersion?.version }
    public var isTemplate: Bool { versions.first(where: { $0.isTemplate }) != nil }

    public var firstReleasedAt: Date? {
        versions.compactMap(\.releasedAt).min()
    }

    public var lastUpdatedAt: Date? {
        versions.compactMap(\.updatedAt).max()
            ?? versions.compactMap(\.releasedAt).max()
    }

    /// Ready-to-paste Typst import snippet for a version (latest by default).
    public func importSnippet(version: SemanticVersion? = nil) -> String {
        let v = version ?? latest ?? SemanticVersion(0, 0, 0)
        return "#import \"@\(namespace.rawValue)/\(name):\(v)\": *"
    }

    /// CLI init command for a version (latest by default).
    public func initCommand(version: SemanticVersion? = nil) -> String {
        let v = version ?? latest ?? SemanticVersion(0, 0, 0)
        return "typst init @\(namespace.rawValue)/\(name):\(v)"
    }
}
