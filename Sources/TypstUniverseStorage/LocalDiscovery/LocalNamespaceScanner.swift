import Foundation
import TypstUniverseCore

/// Scans `@local` / custom package dirs, parses each `typst.toml`,
/// and merges results into the unified catalog (FR-4.6).
public struct LocalNamespaceScanner: Sendable {
    public var directories: [URL]
    public init(directories: [URL]) { self.directories = directories }

    public func scan() async -> [UniversePackage] {
        var versions: [PackageVersion] = []
        for dir in directories {
            versions.append(contentsOf: scanOne(dir))
        }
        return VersionGrouper.group(versions)
    }

    private func scanOne(_ root: URL) -> [PackageVersion] {
        let fm = FileManager.default
        var out: [PackageVersion] = []
        // Layout: root/{namespace}/{name}/{version}/typst.toml (same as cache).
        for ns in ((try? fm.contentsOfDirectory(atPath: root.path)) ?? []) {
            let nsURL = root.appending(path: ns, directoryHint: .isDirectory)
            for name in ((try? fm.contentsOfDirectory(atPath: nsURL.path)) ?? []) {
                let nameURL = nsURL.appending(path: name, directoryHint: .isDirectory)
                for ver in ((try? fm.contentsOfDirectory(atPath: nameURL.path)) ?? []) {
                    guard let v = SemanticVersion(ver) else { continue }
                    let manifestURL = nameURL.appending(path: ver).appending(path: "typst.toml")
                    guard let text = try? String(contentsOf: manifestURL, encoding: .utf8),
                        let m = try? TypstTomlParser.parseManifest(text, package: name)
                    else { continue }
                    out.append(PackageVersion(
                        name: m.package.name, version: v,
                        namespace: TypstNamespace(rawValue: ns),
                        description: m.package.description ?? "",
                        authors: m.package.authors.map { PackageAuthor(name: $0) },
                        license: m.package.license,
                        keywords: m.package.keywords,
                        categories: m.package.categories,
                        disciplines: m.package.disciplines,
                        compilerVersion: m.package.compiler,
                        template: m.template
                    ))
                }
            }
        }
        return out
    }
}
