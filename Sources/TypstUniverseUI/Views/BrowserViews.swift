import SwiftUI
import TypstUniverseCore
import TypstUniverseStorage

public struct CategorySidebarView: View {
    @Bindable var model: UniverseBrowserModel
    public init(model: UniverseBrowserModel) { self.model = model }

    public var body: some View {
        List(selection: Binding(
            get: { model.query.categories.first },
            set: { newValue in
                var q = model.query
                q.categories = newValue.map { [$0] } ?? []
                model.update(query: q)
            }
        )) {
            Section("Library") {
                ForEach(UniverseCategory.allCases, id: \.rawValue) { cat in
                    HStack {
                        Text(cat.displayName)
                        Spacer()
                        if let n = model.counts[cat] { Text("\(n)").foregroundStyle(.secondary) }
                    }
                    .tag(cat)
                    .accessibilityLabel("\(cat.displayName), \(model.counts[cat] ?? 0) packages")
                }
            }
        }
        .navigationTitle("Categories")
    }
}

public struct PackageGridView: View {
    @Bindable var model: UniverseBrowserModel
    public var onSelect: (UniversePackage) -> Void
    public init(model: UniverseBrowserModel, onSelect: @escaping (UniversePackage) -> Void = { _ in }) {
        self.model = model; self.onSelect = onSelect
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                ForEach(model.results, id: \.id) { pkg in
                    Button { onSelect(pkg) } label: {
                        TemplateCardView(package: pkg)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

public struct TypstUniverseBrowserView: View {
    @Bindable var model: UniverseBrowserModel
    @State private var searchText = ""
    @Environment(\.typstUniverseConfiguration) private var config

    public init(model: UniverseBrowserModel) { self.model = model }

    public var body: some View {
        NavigationSplitView {
            CategorySidebarView(model: model)
        } detail: {
            NavigationStack {
                VStack {
                    Picker("Kind", selection: Binding(
                        get: { model.query.kind },
                        set: { k in var q = model.query; q.kind = k; model.update(query: q) }
                    )) {
                        Text("All").tag(PackageKindFilter.all)
                        Text("Templates").tag(PackageKindFilter.templatesOnly)
                        Text("Libraries").tag(PackageKindFilter.packagesOnly)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .accessibilityLabel("Kind filter")
                    switch model.phase {
                    case .loading, .idle:
                        ProgressView("Loading catalog…")
                    case .empty:
                        ContentUnavailableView.search(text: searchText)
                    case let .offline(msg):
                        ContentUnavailableView("Offline", systemImage: "wifi.slash", description: Text(msg))
                    case .loaded:
                        PackageGridView(model: model) { model.select($0) }
                    }
                }
                .searchable(text: $searchText, prompt: "Search templates and packages")
                .onChange(of: searchText) { _, new in
                    var q = model.query
                    q.text = new
                    if let locked = config.lockedKind { q.kind = locked }
                    model.update(query: q)
                }
                .navigationTitle("Typst Universe")
                .navigationDestination(item: Binding(
                    get: { model.selected },
                    set: { model.selected = $0 }
                )) { pkg in
                    PackageDetailView(package: pkg, version: model.selectedVersion)
                }
            }
        }
        .task { await model.load() }
    }
}

public struct TemplatePickerSheet: View {
    @State private var model: UniverseBrowserModel
    private var initialCategory: UniverseCategory?
    private var destinationProvider: (PackageSpec) -> URL
    private var onDone: (ScaffoldedTemplateProject) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.onTemplateScaffoldedKey) private var onScaffolded
    @State private var progress: Double?

    public init(
        client: TypstUniverseClient,
        initialCategory: UniverseCategory? = nil,
        destinationProvider: @escaping (PackageSpec) -> URL,
        onScaffolded done: @escaping (ScaffoldedTemplateProject) -> Void
    ) {
        _model = State(initialValue: UniverseBrowserModel(client: client))
        self.initialCategory = initialCategory
        self.destinationProvider = destinationProvider
        self.onDone = done
    }

    public var body: some View {
        NavigationStack {
            TypstUniverseBrowserView(model: model)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Use Template") { Task { await useSelected() } }
                            .disabled(model.selected == nil)
                    }
                }
        }
        .onAppear {
            if let initialCategory {
                var q = model.query
                q.categories = [initialCategory]
                q.kind = .templatesOnly
                model.update(query: q)
            }
        }
    }

    private func useSelected() async {
        guard let pkg = model.selected, let version = model.selectedVersion ?? pkg.latestVersion else { return }
        let spec = PackageSpec(namespace: pkg.namespace, name: pkg.name, version: version.version)
        // Scaffold via shared client through a fresh fetch path is owned by host;
        // here we surface selection and let host scaffold, to keep sheet testable.
        // For the turnkey path, hosts typically call client.scaffoldTemplate themselves.
        _ = destinationProvider(spec)
        progress = 1
    }
}
