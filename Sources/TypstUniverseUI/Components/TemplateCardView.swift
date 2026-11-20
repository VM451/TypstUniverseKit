import SwiftUI
import TypstUniverseCore
import TypstUniverseStorage

public struct TemplateCardView: View {
    public var package: UniversePackage
    public var version: PackageVersion?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(package: UniversePackage, version: PackageVersion? = nil) {
        self.package = package; self.version = version
    }

    private var shown: PackageVersion? { version ?? package.latestVersion }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailView(package: package, version: shown)
            Text(package.name)
                .font(.headline)
                .lineLimit(1)
            Text(shown?.description ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                if let v = shown?.version { VersionBadge(version: v) }
                if package.isTemplate {
                    Text("Template").font(.caption).foregroundStyle(.secondary)
                }
                if package.isOfficialTemplate {
                    Text("Official")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                        .accessibilityLabel("Official Typst team template")
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(package.name), \(shown?.description ?? "")")
    }
}

struct ThumbnailView: View {
    var package: UniversePackage
    var version: PackageVersion?
    @State private var data: Data?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .aspectRatio(4/3, contentMode: .fit)
            if let data, let image = makeImage(data) {
                #if canImport(UIKit)
                Image(uiImage: image).resizable().scaledToFill()
                #elseif canImport(AppKit)
                Image(nsImage: image).resizable().scaledToFill()
                #endif
            } else {
                Image(systemName: package.isTemplate ? "doc.richtext" : "shippingbox")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task { await load() }
    }

    private func load() async {
        guard let spec = spec() else { return }
        let registry = OfficialUniverseRegistry()
        guard let url = registry.thumbnailURL(for: spec, full: false) else { return }
        data = await ThumbnailPipeline.shared.data(for: url)
    }

    private func spec() -> PackageSpec? {
        guard let v = version ?? package.latestVersion else { return nil }
        return PackageSpec(namespace: package.namespace, name: package.name, version: v.version)
    }

    #if canImport(UIKit)
    private func makeImage(_ data: Data) -> UIImage? { UIImage(data: data) }
    #elseif canImport(AppKit)
    private func makeImage(_ data: Data) -> NSImage? { NSImage(data: data) }
    #endif
}
