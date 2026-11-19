import Foundation

/// Index entries grouped by `(namespace, name)` into packages with
/// semver-sorted versions. Pure function for testability.
public enum VersionGrouper {
    public static func group(_ versions: [PackageVersion]) -> [UniversePackage] {
        var buckets: [String: [PackageVersion]] = [:]
        for v in versions {
            let key = "\(v.namespace.rawValue)/\(v.name)"
            buckets[key, default: []].append(v)
        }
        return buckets.values.map { list in
            let first = list[0]
            return UniversePackage(namespace: first.namespace, name: first.name, versions: list)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Decodes the flat `index.json` array with lenient fallbacks: unknown
/// fields are ignored, missing optionals default, malformed dates become nil.
public enum IndexDecoder {
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    public static func decode(_ data: Data) throws -> [UniversePackage] {
        do {
            let versions = try decoder.decode([PackageVersion].self, from: data)
            return VersionGrouper.group(versions)
        } catch {
            throw TypstUniverseError.indexDecodeFailed(underlying: String(describing: error))
        }
    }
}
