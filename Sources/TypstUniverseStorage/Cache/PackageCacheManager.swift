import Foundation
import TypstUniverseCore

public struct CachePolicy: Sendable, Hashable {
    public var maxBytes: Int
    public var maxAge: TimeInterval?
    public init(maxBytes: Int = 250_000_000, maxAge: TimeInterval? = nil) {
        self.maxBytes = maxBytes
        self.maxAge = maxAge
    }
}

/// Disk index store: caches index.json + ETag for stale-while-revalidate (FR-1.3).
public actor DiskIndexStore {
    private let dir: URL
    private let fm = FileManager.default
    public init(directory: URL) { self.dir = directory }

    private var indexURL: URL { dir.appending(path: "index.json") }
    private var etagURL: URL { dir.appending(path: "index.etag") }

    public func load() throws -> (data: Data, etag: String?)? {
        guard fm.fileExists(atPath: indexURL.path) else { return nil }
        let data = try Data(contentsOf: indexURL)
        let etag = try? String(contentsOf: etagURL, encoding: .utf8)
        return (data, etag?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public func save(data: Data, etag: String?) throws {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: indexURL, options: .atomic)
        if let etag { try etag.write(to: etagURL, atomically: true, encoding: .utf8) }
    }
}

public enum DownloadProgress: Sendable {
    case queued
    case downloading(Double)
    case extracting
    case installed(URL)
    case failed(TypstUniverseError)
}

/// Concurrent, cancellable, deduplicated downloader + Typst-layout cache (FR-4).
public actor PackageCacheManager {
    public struct Configuration: Sendable {
        public var storageRoot: URL
        public var policy: CachePolicy
        public init(storageRoot: URL, policy: CachePolicy = CachePolicy()) {
            self.storageRoot = storageRoot
            self.policy = policy
        }
    }

    private let config: Configuration
    private let registry: any TypstRegistryProvider
    private let session: URLSession
    private var inFlight: [String: Task<URL, Error>] = [:]
    private let fm = FileManager.default

    public init(config: Configuration, registry: any TypstRegistryProvider, session: URLSession = .shared) {
        self.config = config
        self.registry = registry
        self.session = session
    }

    public static func defaultStorageRoot() -> URL {
        #if os(macOS)
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        #else
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        #endif
        return base.appending(path: "TypstUniverse/packages", directoryHint: .isDirectory)
    }

    public func packageDir(for spec: PackageSpec) -> URL {
        config.storageRoot
            .appending(path: spec.namespace.rawValue, directoryHint: .isDirectory)
            .appending(path: spec.name, directoryHint: .isDirectory)
            .appending(path: spec.version.description, directoryHint: .isDirectory)
    }

    public func isInstalled(_ spec: PackageSpec) -> Bool {
        fm.fileExists(atPath: packageDir(for: spec).appending(path: "typst.toml").path)
    }

    /// Download + securely extract. Concurrent callers for the same spec share one task.
    public func fetch(_ spec: PackageSpec) -> AsyncStream<DownloadProgress> {
        AsyncStream { continuation in
            continuation.yield(.queued)
            let task = Task {
                try await self.fetchOnce(spec, report: { continuation.yield($0) })
            }
            Task {
                do {
                    let url = try await task.value
                    continuation.yield(.installed(url))
                } catch is CancellationError {
                    continuation.yield(.failed(.cancelled))
                } catch let e as TypstUniverseError {
                    continuation.yield(.failed(e))
                } catch {
                    continuation.yield(.failed(.network(underlying: String(describing: error))))
                }
                continuation.finish()
            }
        }
    }

    private func fetchOnce(_ spec: PackageSpec, report: @Sendable @escaping (DownloadProgress) -> Void) async throws -> URL {
        let key = spec.description
        if let existing = inFlight[key] { return try await existing.value }
        let task: Task<URL, Error> = Task {
            let dest = self.packageDir(for: spec)
            if self.isInstalled(spec) { return dest }
            report(.downloading(0))
            let url = self.registry.archiveURL(for: spec)
            guard url.scheme == "https" else { throw TypstUniverseError.unsupportedPlatform("non-HTTPS archive URL") }
            let (tmpData, response): (Data, URLResponse)
            do {
                (tmpData, response) = try await self.session.data(from: url)
            } catch is CancellationError { throw CancellationError() }
            catch is URLError { throw TypstUniverseError.offline }
            catch { throw TypstUniverseError.network(underlying: String(describing: error)) }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw TypstUniverseError.httpStatus(http.statusCode, url: url)
            }
            report(.extracting)
            let tar = try SecureTarGzExtractor.gunzip(tmpData)
            let entries = try SecureTarGzExtractor.extractTar(tar)
            // Atomic install via staging dir.
            let staging = self.config.storageRoot.appending(path: "tmp/.staging-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging) }
            for e in entries {
                let out = staging.appending(path: e.path)
                try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
                try e.data.write(to: out, options: .atomic)
            }
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: staging, to: dest)
            report(.downloading(1))
            try await self.enforceCap()
            return dest
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    // MARK: - Cache management (FR-4.5)

    public func installedPackages() throws -> [(spec: PackageSpec, size: Int)] {
        var out: [(PackageSpec, Int)] = []
        guard fm.fileExists(atPath: config.storageRoot.path) else { return out }
        for ns in (try? fm.contentsOfDirectory(atPath: config.storageRoot.path)) ?? [] {
            let nsURL = config.storageRoot.appending(path: ns)
            for name in (try? fm.contentsOfDirectory(atPath: nsURL.path)) ?? [] {
                let nameURL = nsURL.appending(path: name)
                for ver in (try? fm.contentsOfDirectory(atPath: nameURL.path)) ?? [] {
                    if let v = SemanticVersion(ver) {
                        let spec = PackageSpec(namespace: TypstNamespace(rawValue: ns), name: name, version: v)
                        out.append((spec, (try? footprint(of: packageDir(for: spec))) ?? 0))
                    }
                }
            }
        }
        return out
    }

    public func footprint() throws -> Int {
        try footprint(of: config.storageRoot)
    }

    private func footprint(of url: URL) throws -> Int {
        var total = 0
        guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        for case let f as URL in e {
            total += (try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }

    public func remove(_ spec: PackageSpec) throws {
        try? fm.removeItem(at: packageDir(for: spec))
    }

    public func purge() throws {
        if fm.fileExists(atPath: config.storageRoot.path) {
            try fm.removeItem(at: config.storageRoot)
        }
        try fm.createDirectory(at: config.storageRoot, withIntermediateDirectories: true)
    }

    private func enforceCap() throws {
        // Best-effort LRU by modification date.
        var items: [(url: URL, date: Date, size: Int)] = []
        guard fm.fileExists(atPath: config.storageRoot.path) else { return }
        for ns in (try? fm.contentsOfDirectory(atPath: config.storageRoot.path)) ?? [] {
            if ns == "tmp" { continue }
            let nsURL = config.storageRoot.appending(path: ns)
            for name in (try? fm.contentsOfDirectory(atPath: nsURL.path)) ?? [] {
                for ver in (try? fm.contentsOfDirectory(atPath: nsURL.appending(path: name).path)) ?? [] {
                    let u = nsURL.appending(path: name).appending(path: ver)
                    let vals = try? u.resourceValues(forKeys: [.contentModificationDateKey])
                    items.append((u, vals?.contentModificationDate ?? .distantPast, (try? footprint(of: u)) ?? 0))
                }
            }
        }
        var total = items.reduce(0) { $0 + $1.size }
        for item in items.sorted(by: { $0.date < $1.date }) {
            if total <= config.policy.maxBytes { break }
            try? fm.removeItem(at: item.url)
            total -= item.size
        }
    }
}
