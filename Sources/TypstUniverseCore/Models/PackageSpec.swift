/// Registry namespace: `@preview`, `@local`, or a custom enterprise namespace.
///
/// A struct (not an enum) so future/private namespaces decode without
/// breaking existing clients.
public struct TypstNamespace: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let preview = TypstNamespace(rawValue: "preview")
    public static let local = TypstNamespace(rawValue: "local")

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.rawValue = try c.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Canonical `@namespace/name:version` coordinate, e.g. `@preview/cetz:0.3.1`.
public struct PackageSpec: Sendable, Hashable, Codable, CustomStringConvertible {
    public var namespace: TypstNamespace
    public var name: String
    public var version: SemanticVersion

    public init(namespace: TypstNamespace, name: String, version: SemanticVersion) {
        self.namespace = namespace
        self.name = name
        self.version = version
    }

    /// Parses `@preview/cetz:0.3.1`, `@preview/cetz`, `cetz:0.3.1` (preview assumed).
    public init?(_ string: String) {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("@") { s.removeFirst() }
        let nsSplit = s.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        var namespace = TypstNamespace.preview
        var rest: Substring
        if nsSplit.count == 2 {
            namespace = TypstNamespace(rawValue: String(nsSplit[0]))
            rest = nsSplit[1]
        } else {
            rest = nsSplit[0]
        }
        let verSplit = rest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard !verSplit[0].isEmpty else { return nil }
        let name = String(verSplit[0])
        let version: SemanticVersion
        if verSplit.count == 2 {
            guard let v = SemanticVersion(String(verSplit[1])) else { return nil }
            version = v
        } else {
            // Version-less spec is not a full spec; reject to keep semantics strict.
            return nil
        }
        self.init(namespace: namespace, name: name, version: version)
    }

    public var description: String { "@\(namespace.rawValue)/\(name):\(version)" }

    /// Archive filename: `{name}-{version}.tar.gz`.
    public var archiveFilename: String { "\(name)-\(version).tar.gz" }
}
