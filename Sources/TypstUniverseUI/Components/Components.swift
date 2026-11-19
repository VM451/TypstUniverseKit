import SwiftUI
import TypstUniverseCore

public struct CategoryPill: View {
    public var category: UniverseCategory
    public var count: Int?
    public var isSelected: Bool
    public var action: () -> Void

    public init(category: UniverseCategory, count: Int? = nil, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.category = category; self.count = count; self.isSelected = isSelected; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(category.displayName)
                if let count { Text("\(count)").opacity(0.7) }
            }
            .font(.caption)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.displayName) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public struct VersionBadge: View {
    public var version: SemanticVersion
    public init(version: SemanticVersion) { self.version = version }
    public var body: some View {
        Text(version.description)
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Version \(version.description)")
    }
}

public struct ImportCopyButton: View {
    public var snippet: String
    @Environment(\.onPackageImportCopiedKey) private var onCopied
    @State private var copied = false

    public init(snippet: String) { self.snippet = snippet }

    public var body: some View {
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = snippet
            #elseif canImport(AppKit)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippet, forType: .string)
            #endif
            copied = true
            onCopied?(snippet)
        } label: {
            Label(copied ? "Copied" : "Copy import", systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Copy import snippet")
        .accessibilityHint(snippet)
    }
}
