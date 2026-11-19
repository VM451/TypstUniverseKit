import Foundation
import TypstUniverseCore

public enum ConflictPolicy: Sendable, Hashable {
    case failIfNonEmpty
    case overwrite
    case createSubdirectory(named: String)
}

public struct ScaffoldedTemplateProject: Sendable, Hashable, Codable {
    public var spec: PackageSpec
    public var destinationRoot: URL
    public var entrypointURL: URL
    public var files: [String]
    public init(spec: PackageSpec, destinationRoot: URL, entrypointURL: URL, files: [String]) {
        self.spec = spec
        self.destinationRoot = destinationRoot
        self.entrypointURL = entrypointURL
        self.files = files
    }
}

/// `typst init` equivalent (FR-5): copy `{package}/template/*` → destination.
public struct TemplateScaffolder: Sendable {
    private let cache: PackageCacheManager
    public init(cache: PackageCacheManager) { self.cache = cache }

    /// Disk mode: ensures download, validates `[template]`, copies tree.
    public func scaffold(_ spec: PackageSpec, to destination: URL, conflictPolicy: ConflictPolicy = .failIfNonEmpty) async throws -> ScaffoldedTemplateProject {
        var dest = destination
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) {
            let contents = (try? fm.contentsOfDirectory(atPath: dest.path)) ?? []
            switch conflictPolicy {
            case .failIfNonEmpty:
                if !contents.isEmpty { throw TypstUniverseError.destinationConflict(path: dest.path) }
            case .overwrite:
                break
            case let .createSubdirectory(named):
                dest = dest.appending(path: named, directoryHint: .isDirectory)
                try fm.createDirectory(at: dest, withIntermediateDirectories: true)
            }
        } else {
            try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        }
        // Ensure package present.
        let pkgDir: URL
        if await cache.isInstalled(spec) {
            pkgDir = await cache.packageDir(for: spec)
        } else {
            var installed: URL?
            for await p in await cache.fetch(spec) {
                if case let .installed(url) = p { installed = url; break }
                if case let .failed(e) = p { throw e }
            }
            guard let found = installed else {
                throw TypstUniverseError.packageNotInstalled(spec: spec.description)
            }
            pkgDir = found
        }
        let manifestURL = pkgDir.appending(path: "typst.toml")
        guard fm.fileExists(atPath: manifestURL.path) else { throw TypstUniverseError.manifestMissing(package: spec.name) }
        let text = try String(contentsOf: manifestURL, encoding: .utf8)
        let manifest: TypstManifest
        do { manifest = try TypstTomlParser.parseManifest(text, package: spec.name) }
        catch { throw TypstUniverseError.manifestInvalid(package: spec.name, underlying: String(describing: error)) }
        guard let template = manifest.template else { throw TypstUniverseError.templateNotFound(package: spec.name) }
        let templateRoot = pkgDir.appending(path: template.path, directoryHint: .isDirectory)
        guard fm.fileExists(atPath: templateRoot.path) else { throw TypstUniverseError.templateNotFound(package: spec.name) }
        var created: [String] = []
        let enumerated = Self.allEntries(under: templateRoot)
        for src in enumerated {
            let rel = Self.relativePath(of: src, under: templateRoot)
            guard !rel.isEmpty else { continue }
            // Refuse to escape: enumerator output is already under templateRoot.
            guard !rel.contains("..") else { continue }
            let dst = dest.appending(path: rel)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: src.path, isDirectory: &isDir), isDir.boolValue {
                try fm.createDirectory(at: dst, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
                try fm.copyItem(at: src, to: dst)
                created.append(rel)
            }
        }
        let entry = dest.appending(path: template.entrypoint)
        return ScaffoldedTemplateProject(spec: spec, destinationRoot: dest, entrypointURL: entry, files: created.sorted())
    }

    nonisolated private static func allEntries(under root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var out: [URL] = []
        for case let u as URL in enumerator { out.append(u) }
        return out
    }

    nonisolated private static func relativePath(of src: URL, under root: URL) -> String {
        let rootComps = root.standardizedFileURL.pathComponents
        let srcComps = src.standardizedFileURL.pathComponents
        guard srcComps.count >= rootComps.count,
            Array(srcComps.prefix(rootComps.count)) == rootComps
        else {
            return src.lastPathComponent
        }
        return Array(srcComps.dropFirst(rootComps.count)).joined(separator: "/")
    }

    /// In-memory mode for FileWrapper / SwiftData hosts: returns `[relativePath: Data]`.
    public func scaffoldInMemory(_ spec: PackageSpec) async throws -> [String: Data] {
        let pkgDir: URL
        if await cache.isInstalled(spec) {
            pkgDir = await cache.packageDir(for: spec)
        } else {
            var last: URL?
            for await p in await cache.fetch(spec) {
                if case let .installed(url) = p { last = url }
                if case let .failed(e) = p { throw e }
            }
            guard let last else { throw TypstUniverseError.packageNotInstalled(spec: spec.description) }
            pkgDir = last
        }
        let fm = FileManager.default
        let text = try String(contentsOf: pkgDir.appending(path: "typst.toml"), encoding: .utf8)
        let manifest = try TypstTomlParser.parseManifest(text, package: spec.name)
        guard let template = manifest.template else { throw TypstUniverseError.templateNotFound(package: spec.name) }
        let root = pkgDir.appending(path: template.path, directoryHint: .isDirectory)
        var out: [String: Data] = [:]
        for src in Self.allEntries(under: root) {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: src.path, isDirectory: &isDir), !isDir.boolValue {
                let rel = Self.relativePath(of: src, under: root)
                out[rel] = try Data(contentsOf: src)
            }
        }
        return out
    }
}
