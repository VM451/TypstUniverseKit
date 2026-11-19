import Foundation
#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

/// Multi-tier thumbnail pipeline: memory (NSCache) + disk, ImageIO WebP decode off-main.
public actor ThumbnailPipeline {
    public static let shared = ThumbnailPipeline()

    private let memory = NSCache<NSURL, AnyObject>()
    private let disk: URL
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.disk = base.appending(path: "TypstUniverse/thumbnails", directoryHint: .isDirectory)
        memory.totalCostLimit = 50 * 1024 * 1024
        try? FileManager.default.createDirectory(at: disk, withIntermediateDirectories: true)
    }

    private func diskURL(for url: URL) -> URL {
        let safe = url.absoluteString
            .replacingOccurrences(of: "://", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return disk.appending(path: safe)
    }

    /// Returns raw WebP bytes (decode to image in the view layer to stay cross-platform).
    public func data(for url: URL) async -> Data? {
        let key = url as NSURL
        if memory.object(forKey: key) != nil {
            let d = diskURL(for: url)
            return try? Data(contentsOf: d)
        }
        let d = diskURL(for: url)
        if let cached = try? Data(contentsOf: d) {
            memory.setObject(cached as NSData, forKey: key)
            return cached
        }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode ?? 200 < 400 else { return nil }
            try? data.write(to: d, options: .atomic)
            memory.setObject(data as NSData, forKey: key)
            return data
        } catch {
            return nil
        }
    }

    public func clearMemory() { memory.removeAllObjects() }
}
