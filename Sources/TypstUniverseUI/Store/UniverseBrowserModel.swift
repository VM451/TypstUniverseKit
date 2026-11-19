import Foundation
import TypstUniverseCore
import TypstUniverseStorage

/// Presentation state machine for the browser (loading/loaded/empty/offline).
@MainActor
@Observable
public final class UniverseBrowserModel {
    public enum Phase: Sendable, Hashable {
        case idle
        case loading
        case loaded
        case empty
        case offline(String)
    }

    public var query = UniverseQuery()
    public var catalog: [UniversePackage] = []
    public var results: [UniversePackage] = []
    public var counts: [UniverseCategory: Int] = [:]
    public var phase: Phase = .idle
    public var selected: UniversePackage?
    public var selectedVersion: PackageVersion?

    private let engine = UniverseSearchEngine()
    private var client: TypstUniverseClient?

    public init(client: TypstUniverseClient? = nil) {
        self.client = client
    }

    public func attach(client: TypstUniverseClient) {
        self.client = client
    }

    public func setCatalog(_ catalog: [UniversePackage]) {
        self.catalog = catalog
        apply()
    }

    public func update(query: UniverseQuery) {
        self.query = query
        apply()
    }

    private func apply() {
        results = engine.search(catalog, query: query)
        counts = engine.categoryCounts(results.isEmpty ? catalog : results)
        if catalog.isEmpty {
            phase = .loading
        } else if results.isEmpty {
            phase = .empty
        } else {
            phase = .loaded
        }
    }

    public func load() async {
        phase = .loading
        guard let client else { phase = .offline("No registry client configured."); return }
        do {
            let catalog = try await client.syncCatalog()
            setCatalog(catalog)
        } catch let e as TypstUniverseError {
            phase = .offline(e.errorDescription ?? "Offline")
        } catch {
            phase = .offline(String(describing: error))
        }
    }

    public func retry() async { await load() }

    public func select(_ pkg: UniversePackage, version: PackageVersion? = nil) {
        selected = pkg
        selectedVersion = version ?? pkg.latestVersion
    }
}
