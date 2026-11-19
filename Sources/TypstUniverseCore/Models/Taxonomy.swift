/// The 19 official Typst Universe categories, grouped for UI browsing.
///
/// A struct with static constants (not an enum) so unknown future
/// categories decode cleanly into `.custom(rawValue)` instead of failing
/// the whole catalog load.
public struct UniverseCategory: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible, CaseIterable {
    public var rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    // Document & Template Categories (9)
    public static let book = UniverseCategory(rawValue: "book")
    public static let report = UniverseCategory(rawValue: "report")
    public static let paper = UniverseCategory(rawValue: "paper")
    public static let thesis = UniverseCategory(rawValue: "thesis")
    public static let poster = UniverseCategory(rawValue: "poster")
    public static let flyer = UniverseCategory(rawValue: "flyer")
    public static let presentation = UniverseCategory(rawValue: "presentation")
    public static let cv = UniverseCategory(rawValue: "cv")
    public static let office = UniverseCategory(rawValue: "office")
    // Library & Tooling Categories (10)
    public static let components = UniverseCategory(rawValue: "components")
    public static let visualization = UniverseCategory(rawValue: "visualization")
    public static let model = UniverseCategory(rawValue: "model")
    public static let layout = UniverseCategory(rawValue: "layout")
    public static let text = UniverseCategory(rawValue: "text")
    public static let languages = UniverseCategory(rawValue: "languages")
    public static let scripting = UniverseCategory(rawValue: "scripting")
    public static let integration = UniverseCategory(rawValue: "integration")
    public static let utility = UniverseCategory(rawValue: "utility")
    public static let fun = UniverseCategory(rawValue: "fun")

    public static var allCases: [UniverseCategory] {
        [.book, .report, .paper, .thesis, .poster, .flyer, .presentation, .cv, .office,
         .components, .visualization, .model, .layout, .text, .languages, .scripting,
         .integration, .utility, .fun]
    }

    /// `true` when this is one of the 19 known categories.
    public var isOfficial: Bool { Self.allCases.contains(self) }

    public var description: String { rawValue }

    /// Human-readable display name for UI.
    public var displayName: String {
        switch self {
        case .cv: return "CV"
        case .components: return "Components"
        case .visualization: return "Visualization"
        default: return rawValue.capitalized
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.rawValue = try c.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// Official Typst disciplines (e.g. computer-science, mathematics, …).
///
/// Extensible struct: unknown future disciplines decode without breaking.
public struct UniverseDiscipline: Sendable, Hashable, Codable, RawRepresentable, CustomStringConvertible, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    // Commonly used disciplines (non-exhaustive; any string is valid).
    public static let computerScience = UniverseDiscipline(rawValue: "computer-science")
    public static let mathematics = UniverseDiscipline(rawValue: "mathematics")
    public static let physics = UniverseDiscipline(rawValue: "physics")
    public static let engineering = UniverseDiscipline(rawValue: "engineering")
    public static let biology = UniverseDiscipline(rawValue: "biology")
    public static let chemistry = UniverseDiscipline(rawValue: "chemistry")
    public static let medicine = UniverseDiscipline(rawValue: "medicine")
    public static let economics = UniverseDiscipline(rawValue: "economics")
    public static let business = UniverseDiscipline(rawValue: "business")
    public static let law = UniverseDiscipline(rawValue: "law")
    public static let education = UniverseDiscipline(rawValue: "education")
    public static let design = UniverseDiscipline(rawValue: "design")
    public static let humanities = UniverseDiscipline(rawValue: "humanities")
    public static let literature = UniverseDiscipline(rawValue: "literature")
    public static let history = UniverseDiscipline(rawValue: "history")
    public static let psychology = UniverseDiscipline(rawValue: "psychology")
    public static let communication = UniverseDiscipline(rawValue: "communication")

    public var description: String { rawValue }

    public var displayName: String {
        rawValue.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.rawValue = try c.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
