import SwiftUI
import TypstUniverseCore
import TypstUniverseStorage

public struct PackageDetailView: View {
    public var package: UniversePackage
    @State private var selectedVersion: PackageVersion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onTemplateSelectedKey) private var onSelected

    public init(package: UniversePackage, version: PackageVersion? = nil) {
        self.package = package
        _selectedVersion = State(initialValue: version ?? package.latestVersion ?? PackageVersion(name: package.name, version: SemanticVersion(0, 0, 0)))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ThumbnailView(package: package, version: selectedVersion)
                    .frame(maxHeight: 320)
                Text(package.name).font(.largeTitle.bold())
                Text(selectedVersion.description).foregroundStyle(.secondary)
                HStack {
                    VersionBadge(version: selectedVersion.version)
                    ForEach(selectedVersion.categories, id: \.rawValue) { Text($0.displayName).font(.caption) }
                }
                .accessibilityElement(children: .combine)
                if !package.versions.isEmpty {
                    Picker("Version", selection: $selectedVersion) {
                        ForEach(package.versions, id: \.version) { v in
                            Text(v.version.description).tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Version picker")
                }
                ImportCopyButton(snippet: package.importSnippet(version: selectedVersion.version))
                Link("View on Typst Universe", destination: portalURL)
            }
            .padding()
        }
        .navigationTitle(package.name)
    }

    private var portalURL: URL {
        URL(string: "https://typst.app/universe/package/\(package.name)/\(selectedVersion.version)")!
    }
}

extension PackageVersion: Identifiable {
    public var id: String { version.description }
}
