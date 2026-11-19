import SwiftUI
import TypstUniverseCore
import TypstUniverseStorage
import TypstUniverseUI

@main
struct UniverseExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var model = UniverseBrowserModel()
    @State private var showingPicker = false
    @State private var lastProject: String = ""

    var body: some View {
        TypstUniverseBrowserView(model: model)
            .typstUniverseConfiguration(TypstUniverseConfiguration())
            .toolbar {
                Button("New from Template") { showingPicker = true }
            }
            .sheet(isPresented: $showingPicker) {
                TemplatePickerSheet(
                    client: TypstUniverseClient.shared,
                    initialCategory: .cv,
                    destinationProvider: { spec in
                        FileManager.default.temporaryDirectory
                            .appending(path: "\(spec.name)-\(UUID().uuidString)")
                    }
                ) { project in
                    lastProject = project.entrypointURL.path
                    showingPicker = false
                }
            }
    }
}
