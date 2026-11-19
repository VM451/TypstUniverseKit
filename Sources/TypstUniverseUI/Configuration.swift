import Foundation
import SwiftUI
import TypstUniverseCore
import TypstUniverseStorage

/// Host configuration for the UI kit (FR-6.3).
public struct TypstUniverseConfiguration: Sendable {
    public var lockedKind: PackageKindFilter?
    public var lockedCategory: UniverseCategory?
    public var accentColor: ColorRepresentable
    public var showImportSnippet: Bool

    public init(
        lockedKind: PackageKindFilter? = nil,
        lockedCategory: UniverseCategory? = nil,
        accentColor: ColorRepresentable = .defaultAccent,
        showImportSnippet: Bool = true
    ) {
        self.lockedKind = lockedKind
        self.lockedCategory = lockedCategory
        self.accentColor = accentColor
        self.showImportSnippet = showImportSnippet
    }
}

/// Codable/Sendable color token (SwiftUI Color itself isn't Codable).
public struct ColorRepresentable: Sendable, Hashable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }
    public static let defaultAccent = ColorRepresentable(red: 0.1, green: 0.45, blue: 1.0)
}

private struct UniverseConfigKey: EnvironmentKey {
    static let defaultValue = TypstUniverseConfiguration()
}

public extension EnvironmentValues {
    var typstUniverseConfiguration: TypstUniverseConfiguration {
        get { self[UniverseConfigKey.self] }
        set { self[UniverseConfigKey.self] = newValue }
    }
}

public extension View {
    func typstUniverseConfiguration(_ config: TypstUniverseConfiguration) -> some View {
        environment(\.typstUniverseConfiguration, config)
    }
    func onTemplateSelected(_ action: @escaping @Sendable (UniversePackage, PackageVersion) -> Void) -> some View {
        environment(\.onTemplateSelectedKey, action)
    }
    func onTemplateScaffolded(_ action: @escaping @Sendable (ScaffoldedTemplateProject) -> Void) -> some View {
        environment(\.onTemplateScaffoldedKey, action)
    }
    func onPackageImportCopied(_ action: @escaping @Sendable (String) -> Void) -> some View {
        environment(\.onPackageImportCopiedKey, action)
    }
}

private struct OnSelectedKey: EnvironmentKey {
    static var defaultValue: (@Sendable (UniversePackage, PackageVersion) -> Void)? { nil }
}
private struct OnScaffoldedKey: EnvironmentKey {
    static var defaultValue: (@Sendable (ScaffoldedTemplateProject) -> Void)? { nil }
}
private struct OnCopiedKey: EnvironmentKey {
    static var defaultValue: (@Sendable (String) -> Void)? { nil }
}

extension EnvironmentValues {
    var onTemplateSelectedKey: (@Sendable (UniversePackage, PackageVersion) -> Void)? {
        get { self[OnSelectedKey.self] }
        set { self[OnSelectedKey.self] = newValue }
    }
    var onTemplateScaffoldedKey: (@Sendable (ScaffoldedTemplateProject) -> Void)? {
        get { self[OnScaffoldedKey.self] }
        set { self[OnScaffoldedKey.self] = newValue }
    }
    var onPackageImportCopiedKey: (@Sendable (String) -> Void)? {
        get { self[OnCopiedKey.self] }
        set { self[OnCopiedKey.self] = newValue }
    }
}

/// Injection point for hosts with a Rust/WASM compiler (§11): live preview beside WebP.
public protocol TypstLivePreviewProviding {
    @MainActor func makePreview(for spec: PackageSpec) -> AnyView
}
