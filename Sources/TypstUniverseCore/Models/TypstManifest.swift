/// Parsed `typst.toml` manifest: `[package]` metadata plus optional `[template]`.
public struct TypstManifest: Sendable, Hashable, Codable {
    public var package: ManifestPackage
    public var template: TemplateInfo?
    public var tool: [String: String]?

    public init(package: ManifestPackage, template: TemplateInfo? = nil) {
        self.package = package
        self.template = template
    }
}

public struct ManifestPackage: Sendable, Hashable, Codable {
    public var name: String
    public var version: SemanticVersion
    public var entrypoint: String
    public var authors: [String]
    public var license: String?
    public var description: String?
    public var repository: String?
    public var homepage: String?
    public var keywords: [String]
    public var categories: [UniverseCategory]
    public var disciplines: [UniverseDiscipline]
    public var compiler: SemanticVersion?

    public init(
        name: String, version: SemanticVersion, entrypoint: String,
        authors: [String] = [], license: String? = nil, description: String? = nil,
        repository: String? = nil, homepage: String? = nil, keywords: [String] = [],
        categories: [UniverseCategory] = [], disciplines: [UniverseDiscipline] = [],
        compiler: SemanticVersion? = nil
    ) {
        self.name = name
        self.version = version
        self.entrypoint = entrypoint
        self.authors = authors
        self.license = license
        self.description = description
        self.repository = repository
        self.homepage = homepage
        self.keywords = keywords
        self.categories = categories
        self.disciplines = disciplines
        self.compiler = compiler
    }
}
