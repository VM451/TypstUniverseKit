import Foundation

/// Pluggable registry source: official Universe, private mirrors, local dirs.
public protocol TypstRegistryProvider: Sendable {
    var id: String { get }
    /// Returns `(packages, etag)`; `packages` is nil on 304 Not Modified.
    func fetchIndex(etag: String?) async throws -> (packages: [UniversePackage]?, etag: String?)
    func archiveURL(for spec: PackageSpec) -> URL
    func thumbnailURL(for spec: PackageSpec, full: Bool) -> URL?
}

/// Official https://packages.typst.org/preview registry with ETag caching.
public struct OfficialUniverseRegistry: TypstRegistryProvider, Sendable {
    public var id: String { "preview" }
    public var baseURL: URL
    public var session: URLSession

    public init(baseURL: URL = URL(string: "https://packages.typst.org/preview")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchIndex(etag: String?) async throws -> (packages: [UniversePackage]?, etag: String?) {
        let url = baseURL.appending(path: "index.json")
        var req = URLRequest(url: url)
        req.setValue("must-revalidate", forHTTPHeaderField: "Cache-Control")
        if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch is URLError {
            throw TypstUniverseError.offline
        } catch {
            throw TypstUniverseError.network(underlying: String(describing: error))
        }
        guard let http = response as? HTTPURLResponse else {
            throw TypstUniverseError.network(underlying: "Non-HTTP response")
        }
        switch http.statusCode {
        case 304:
            return (nil, etag)
        case 200..<300:
            let newEtag = http.value(forHTTPHeaderField: "Etag") ?? http.value(forHTTPHeaderField: "ETag")
            let packages = try IndexDecoder.decode(data)
            return (packages, newEtag)
        default:
            throw TypstUniverseError.httpStatus(http.statusCode, url: url)
        }
    }

    public func archiveURL(for spec: PackageSpec) -> URL {
        baseURL.appending(path: "\(spec.name)-\(spec.version).tar.gz")
    }

    public func thumbnailURL(for spec: PackageSpec, full: Bool) -> URL? {
        let suffix = full ? "\(spec.name)-\(spec.version).webp" : "\(spec.name)-\(spec.version)-small.webp"
        return baseURL.appending(path: "thumbnails/\(suffix)")
    }

    /// Deep link to the web portal.
    public func portalURL(for spec: PackageSpec) -> URL? {
        URL(string: "https://typst.app/universe/package/\(spec.name)/\(spec.version)")
    }
}
