import Foundation

/// Typed errors across TypstUniverseKit, suitable for UI presentation.
public enum TypstUniverseError: Sendable, Error, Hashable {
    case offline
    case httpStatus(Int, url: URL?)
    case network(underlying: String)
    case indexDecodeFailed(underlying: String)
    case archiveSecurityViolation(reason: String)
    case archiveTooLarge(limit: Int)
    case archiveEntryLimitExceeded(limit: Int)
    case templateNotFound(package: String)
    case manifestMissing(package: String)
    case manifestInvalid(package: String, underlying: String)
    case destinationConflict(path: String)
    case diskFull
    case packageNotInstalled(spec: String)
    case unsupportedPlatform(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .offline: return "You appear to be offline. Showing the last synced catalog."
        case let .httpStatus(code, _): return "Registry request failed (HTTP \(code))."
        case .network: return "Network request failed."
        case .indexDecodeFailed: return "Could not parse the package catalog."
        case let .archiveSecurityViolation(reason): return "Blocked unsafe archive entry: \(reason)"
        case let .archiveTooLarge(limit): return "Archive exceeds the \(limit) byte safety limit."
        case let .archiveEntryLimitExceeded(limit): return "Archive exceeds the \(limit) file safety limit."
        case let .templateNotFound(package): return "Package '\(package)' contains no template."
        case let .manifestMissing(package): return "Package '\(package)' has no typst.toml manifest."
        case .manifestInvalid: return "Package manifest is invalid."
        case let .destinationConflict(path): return "Destination already exists: \(path)"
        case .diskFull: return "Not enough disk space."
        case let .packageNotInstalled(spec): return "Package not installed: \(spec)"
        case let .unsupportedPlatform(msg): return "Unsupported platform: \(msg)"
        case .cancelled: return "Cancelled."
        }
    }

    public var failureReason: String? { errorDescription }
}

extension TypstUniverseError: LocalizedError {}
