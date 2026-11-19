import Foundation

/// Strict Semantic Versioning (https://semver.org), `major.minor.patch`
/// with optional pre-release and build metadata.
///
/// Comparison follows semver precedence: numeric identifiers compare
/// numerically (`0.10.0 > 0.2.0`), pre-release versions sort below their
/// release, and pre-release identifiers compare per spec (§11).
public struct SemanticVersion: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    public var major: Int
    public var minor: Int
    public var patch: Int
    public var prerelease: String?
    public var build: String?

    public init(_ major: Int, _ minor: Int, _ patch: Int, prerelease: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = (prerelease?.isEmpty == true) ? nil : prerelease
        self.build = (build?.isEmpty == true) ? nil : build
    }

    public init?(_ string: String) {
        let s = string.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        // Split build metadata first, then prerelease.
        let buildSplit = s.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        let withoutBuild = String(buildSplit[0])
        let build: String? = buildSplit.count > 1 ? String(buildSplit[1]) : nil
        let preSplit = withoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = preSplit[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3,
            let major = Int(core[0]), let minor = Int(core[1]), let patch = Int(core[2]),
            major >= 0, minor >= 0, patch >= 0
        else { return nil }
        // Reject leading zeros per semver (§2): "01" invalid.
        for part in core {
            if part.count > 1 && part.hasPrefix("0") { return nil }
        }
        let prerelease: String? = preSplit.count > 1 ? String(preSplit[1]) : nil
        if let pre = prerelease, pre.isEmpty { return nil }
        if let b = build, b.isEmpty { return nil }
        self.init(major, minor, patch, prerelease: prerelease, build: build)
    }

    public var description: String {
        var s = "\(major).\(minor).\(patch)"
        if let prerelease { s += "-\(prerelease)" }
        if let build { s += "+\(build)" }
        return s
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, _): return false // release > prerelease
        case (_, nil): return true
        case let (l?, r?):
            return comparePrerelease(l, r) == .orderedAscending
        }
    }

    private static func comparePrerelease(_ l: String, _ r: String) -> ComparisonResult {
        let li = l.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let ri = r.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        for (a, b) in zip(li, ri) {
            if a == b { continue }
            let an = Int(a), bn = Int(b)
            switch (an, bn) {
            case let (x?, y?): if x != y { return x < y ? .orderedAscending : .orderedDescending }
            case (_?, nil): return .orderedAscending // numeric < alphanumeric
            case (nil, _?): return .orderedDescending
            case (nil, nil): return a < b ? .orderedAscending : .orderedDescending
            }
        }
        if li.count == ri.count { return .orderedSame }
        return li.count < ri.count ? .orderedAscending : .orderedDescending
    }

    // MARK: - Codable as single string "1.2.3"

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        guard let v = SemanticVersion(s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid semantic version: \(s)")
        }
        self = v
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
