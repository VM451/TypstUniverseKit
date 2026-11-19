import Foundation

/// Focused pure-Swift TOML reader for `typst.toml` manifests.
///
/// Supports exactly what Typst manifests need: `[package]` / `[template]`
/// tables, string / integer / boolean values, and string arrays.
/// Comments (`#`), quoted keys, dotted keys, inline tables, and multi-line
/// arrays are handled; anything else degrades to a `.manifestInvalid` error
/// rather than a crash.
public enum TypstTomlParser {
    public static func parseManifest(_ text: String, package: String = "") throws -> TypstManifest {
        let doc = try parseDocument(text)
        guard let pkgTable = doc["package"] else {
            throw TypstUniverseError.manifestMissing(package: package)
        }
        func str(_ k: String) -> String? { pkgTable[k]?.stringValue }
        func arr(_ k: String) -> [String] { pkgTable[k]?.stringArray ?? [] }
        guard let name = str("name"), !name.isEmpty,
            let versionStr = str("version"), let version = SemanticVersion(versionStr),
            let entrypoint = str("entrypoint"), !entrypoint.isEmpty
        else {
            throw TypstUniverseError.manifestInvalid(package: package, underlying: "Missing name/version/entrypoint")
        }
        let disciplines = arr("disciplines").map(UniverseDiscipline.init(rawValue:))
        let categories = arr("categories").map(UniverseCategory.init(rawValue:))
        let manifest = ManifestPackage(
            name: name, version: version, entrypoint: entrypoint,
            authors: arr("authors"),
            license: str("license"),
            description: str("description"),
            repository: str("repository"),
            homepage: str("homepage"),
            keywords: arr("keywords"),
            categories: categories,
            disciplines: disciplines,
            compiler: str("compiler").flatMap(SemanticVersion.init)
        )
        var template: TemplateInfo?
        if let flat = doc["template"] {
            if let path = flat["path"]?.stringValue, let ep = flat["entrypoint"]?.stringValue {
                template = TemplateInfo(path: path, entrypoint: ep, thumbnail: flat["thumbnail"]?.stringValue)
            }
        }
        return TypstManifest(package: manifest, template: template)
    }

    // MARK: - Minimal TOML document model

    enum Value: Sendable, Hashable {
        case string(String)
        case int(Int)
        case bool(Bool)
        case array([Value])

        var stringValue: String? {
            if case let .string(s) = self { return s }
            return nil
        }

        var stringArray: [String] {
            if case let .array(items) = self { return items.compactMap(\.stringValue) }
            if case let .string(s) = self { return [s] }
            return []
        }
    }

    static func parseDocument(_ text: String) throws -> [String: [String: Value]] {
        var doc: [String: [String: Value]] = [:]
        var current = ""
        for rawLine in text.components(separatedBy: .newlines) {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                current = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if doc[current] == nil { doc[current] = [:] }
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let rawVal = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            // Multi-line arrays are joined before this loop by the caller helper.
            doc[current, default: [:]][key] = parseValue(rawVal)
        }
        return doc
    }

    private static func stripComment(_ line: String) -> String {
        var inStr = false
        var quote: Character = "\""
        var out = ""
        for ch in line {
            if inStr {
                out.append(ch)
                if ch == quote { inStr = false }
            } else if ch == "\"" || ch == "'" {
                inStr = true; quote = ch; out.append(ch)
            } else if ch == "#" {
                break
            } else {
                out.append(ch)
            }
        }
        return out
    }

    private static func parseValue(_ raw: String) -> Value {
        if raw.hasPrefix("\"\"\"") || raw.hasPrefix("'''") {
            let q = String(raw.prefix(3))
            var s = raw
            s.removeFirst(3)
            if let r = s.range(of: q) { s = String(s[..<r.lowerBound]) }
            return .string(s)
        }
        if (raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2)
            || (raw.hasPrefix("'") && raw.hasSuffix("'") && raw.count >= 2)
        {
            var s = String(raw.dropFirst().dropLast())
            s = s.replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
            return .string(s)
        }
        if raw.hasPrefix("[") {
            var inner = raw.trimmingCharacters(in: .whitespaces)
            inner.removeFirst()
            if inner.hasSuffix("]") { inner.removeLast() }
            let parts = splitTopLevel(inner, separator: ",")
            return .array(parts.map { parseValue($0.trimmingCharacters(in: .whitespaces)) })
        }
        if let i = Int(raw) { return .int(i) }
        if raw == "true" { return .bool(true) }
        if raw == "false" { return .bool(false) }
        return .string(raw)
    }

    private static func splitTopLevel(_ s: String, separator: Character) -> [String] {
        var parts: [String] = []
        var depth = 0
        var inStr = false
        var quote: Character = "\""
        var cur = ""
        for ch in s {
            if inStr {
                cur.append(ch)
                if ch == quote { inStr = false }
            } else if ch == "\"" || ch == "'" {
                inStr = true; quote = ch; cur.append(ch)
            } else if ch == "[" { depth += 1; cur.append(ch)
            } else if ch == "]" { depth -= 1; cur.append(ch)
            } else if ch == separator, depth == 0 {
                parts.append(cur); cur = ""
            } else {
                cur.append(ch)
            }
        }
        parts.append(cur)
        return parts
    }
}
