import Foundation
import TypstUniverseCore

/// Headless facade combining registry + cache + search + scaffolding (§7).
public actor TypstUniverseClient {
    public struct Configuration: Sendable {
        public var storageDirectory: URL
        public var registry: any TypstRegistryProvider
        public var includeLocalNamespace: Bool
        public var localDirectories: [URL]
        public var cachePolicy: CachePolicy

        public init(
            storageDirectory: URL,
            registry: any TypstRegistryProvider = OfficialUniverseRegistry(),
            includeLocalNamespace: Bool = true,
            localDirectories: [URL] = [],
            cachePolicy: CachePolicy = CachePolicy()
        ) {
            self.storageDirectory = storageDirectory
            self.registry = registry
            self.includeLocalNamespace = includeLocalNamespace
            self.localDirectories = localDirectories
            self.cachePolicy = cachePolicy
        }
    }

    public static let shared: TypstUniverseClient = .live()

    public static func live(configuration: Configuration? = nil) -> TypstUniverseClient {
        let config = configuration ?? Configuration(storageDirectory: PackageCacheManager.defaultStorageRoot())
        return TypstUniverseClient(configuration: config)
    }

    private let configuration: Configuration
    private let cache: PackageCacheManager
    private let indexStore: DiskIndexStore
    private let scaffolder: TemplateScaffolder
    private var catalog: [UniversePackage] = []

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.cache = PackageCacheManager(
            config: .init(storageRoot: configuration.storageDirectory, policy: configuration.cachePolicy),
            registry: configuration.registry
        )
        self.indexStore = DiskIndexStore(directory: configuration.storageDirectory.appending(path: ".index", directoryHint: .isDirectory))
        self.scaffolder = TemplateScaffolder(cache: cache)
    }

    /// Stale-while-revalidate: returns disk cache immediately, refreshes via ETag.
    public func syncCatalog() async throws -> [UniversePackage] {
        if let cached = try? await indexStore.load(),
            let pkgs = try? IndexDecoder.decode(cached.data)
        {
            catalog = await merged(pkgs)
            // Background revalidation.
            Task { try? await self.revalidate(etag: cached.etag) }
            return catalog
        }
        try await revalidate(etag: nil)
        return catalog
    }

    private func revalidate(etag: String?) async throws {
        do {
            let (pkgs, newEtag) = try await configuration.registry.fetchIndex(etag: etag)
            if let pkgs {
                if let data = try? JSONEncoder().encode(pkgs.flatMap(\.versions)) {
                    try? await indexStore.save(data: data, etag: newEtag)
                }
                catalog = await merged(pkgs)
            }
        } catch {
            if catalog.isEmpty {
                if let cached = try? await indexStore.load(),
                    let pkgs = try? IndexDecoder.decode(cached.data)
                {
                    catalog = await merged(pkgs)
                    return
                }
                throw error
            }
            // Offline with in-memory catalog: keep serving stale.
        }
    }

    private func merged(_ remote: [UniversePackage]) async -> [UniversePackage] {
        guard configuration.includeLocalNamespace else { return remote }
        let local = await LocalNamespaceScanner(directories: configuration.localDirectories).scan()
        if local.isEmpty { return remote }
        // Merge by id; local entries win on name collision (private overrides).
        var byId: [String: UniversePackage] = Dictionary(uniqueKeysWithValues: remote.map { ($0.id, $0) })
        for pkg in local { byId[pkg.id] = pkg }
        return byId.values.sorted { $0.name < $1.name }
    }

    public func search(_ query: UniverseQuery) async -> [UniversePackage] {
        UniverseSearchEngine().search(catalog, query: query)
    }

    public func fetch(_ spec: PackageSpec) async -> AsyncStream<DownloadProgress> {
        await cache.fetch(spec)
    }

    public func scaffoldTemplate(_ spec: PackageSpec, to destination: URL, conflictPolicy: ConflictPolicy = .failIfNonEmpty) async throws -> ScaffoldedTemplateProject {
        try await scaffolder.scaffold(spec, to: destination, conflictPolicy: conflictPolicy)
    }

    public func scaffoldInMemory(_ spec: PackageSpec) async throws -> [String: Data] {
        try await scaffolder.scaffoldInMemory(spec)
    }
}
