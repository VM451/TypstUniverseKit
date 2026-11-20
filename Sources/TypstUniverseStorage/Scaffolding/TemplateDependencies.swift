import Foundation
import TypstUniverseCore

/// Transitive `@preview` dependency closure for installed packages.
///
/// A template package's Typst sources routinely import *other* registry
/// packages (`lib.typ` → `@preview/hydra:0.6.3`), but manifests from this
/// registry era carry no `[dependencies]` table — the imports are the
/// only record. Without this resolver, scaffolding succeeds while the
/// first compile fails with `file not found (searched at typst.toml)`,
/// naming the missing *manifest* rather than the missing package.
///
/// Used by `TemplateScaffolder` after the requested package is on disk,
/// so both preview and use-template flows compile on first open — even
/// for packages cached before this resolver existed (backfill).
public struct TemplateDependencyResolver: Sendable {
    private let cache: PackageCacheManager
    public init(cache: PackageCacheManager) { self.cache = cache }

    /// Ensures `spec` and every transitively imported `@preview`
    /// package is installed. Returns all ensured specs, root first.
    /// Already-installed packages are never re-downloaded (offline
    /// safe); missing ones are fetched, so an unreachable registry
    /// surfaces here — naming the package — instead of as a cryptic
    /// engine error later.
    @discardableResult
    public func ensureInstalledWithDependencies(
        _ spec: PackageSpec,
        maxDepth: Int = 10,
        maxPackages: Int = 64
    ) async throws -> [PackageSpec] {
        var ensured: [PackageSpec] = []
        var seen = Set<String>()
        var queue: [(spec: PackageSpec, depth: Int)] = [(spec, 0)]
        while !queue.isEmpty, ensured.count < maxPackages {
            let (current, depth) = queue.removeFirst()
            guard seen.insert(current.description).inserted else { continue }
            if !(await cache.isInstalled(current)) {
                var installed: URL?
                for await p in await cache.fetch(current) {
                    if case let .installed(url) = p { installed = url; break }
                    if case let .failed(e) = p { throw e }
                }
                guard installed != nil else {
                    throw TypstUniverseError.packageNotInstalled(spec: current.description)
                }
            }
            ensured.append(current)
            guard depth < maxDepth else { continue }
            let dir = await cache.packageDir(for: current)
            for dep in Self.referencedPackages(under: dir) where !seen.contains(dep.description) {
                queue.append((dep, depth + 1))
            }
        }
        return ensured
    }

    /// All `@preview/...` specs imported by `.typ` sources under a
    /// package directory, deduplicated, in first-seen order. Only
    /// fully-versioned `@preview` specs are returned: other
    /// namespaces resolve locally (not via this cache), and partial
    /// versions cannot be pinned to a tarball.
    public static func referencedPackages(under dir: URL) -> [PackageSpec] {
        var out: [PackageSpec] = []
        var seen = Set<String>()
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return out
        }
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "typ",
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            for spec in referencedPackages(in: text) where seen.insert(spec.description).inserted {
                out.append(spec)
            }
        }
        return out.sorted { $0.description < $1.description }
    }

    /// Pure scanner for one source text. Matches
    /// `#import "@preview/name:1.2.3"`, with any spacing, anywhere in
    /// the file (comments included — over-approximating only ever
    /// pre-fetches a cache entry, never miscompiles).
    public static func referencedPackages(in source: String) -> [PackageSpec] {
        var out: [PackageSpec] = []
        var seen = Set<String>()
        var rest = source[...]
        while let hashRange = rest.range(of: "#import") {
            rest = rest[hashRange.upperBound...]
            guard let quote = rest.firstIndex(of: "\"") else { break }
            let afterQuote = rest[rest.index(after: quote)...]
            guard let end = afterQuote.firstIndex(of: "\"") else { break }
            let literal = String(afterQuote[..<end])
            rest = afterQuote[end...]
            guard literal.hasPrefix("@"),
                  let spec = PackageSpec(literal),
                  spec.namespace == .preview
            else { continue }
            if seen.insert(spec.description).inserted { out.append(spec) }
        }
        return out
    }
}
