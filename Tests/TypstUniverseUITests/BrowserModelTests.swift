import XCTest
@testable import TypstUniverseCore
@testable import TypstUniverseStorage
@testable import TypstUniverseUI

@MainActor
final class BrowserModelTests: XCTestCase {
    private func sample() -> [UniversePackage] {
        [UniversePackage(namespace: .preview, name: "basic-resume", versions: [
            PackageVersion(name: "basic-resume", version: SemanticVersion(0, 2, 8), description: "Resume", categories: [.cv], updatedAt: Date(), releasedAt: Date(), template: TemplateInfo(path: "t", entrypoint: "main.typ"))
        ])]
    }

    func testEmptyQueryLoadsAll() {
        let m = UniverseBrowserModel()
        m.setCatalog(sample())
        XCTAssertEqual(m.phase, .loaded)
        XCTAssertEqual(m.results.count, 1)
    }

    func testEmptySearchState() {
        let m = UniverseBrowserModel()
        m.setCatalog(sample())
        m.update(query: UniverseQuery(text: "zzz-no-match"))
        XCTAssertEqual(m.phase, .empty)
        XCTAssertTrue(m.results.isEmpty)
    }

    func testCategoryCounts() {
        let m = UniverseBrowserModel()
        m.setCatalog(sample())
        XCTAssertEqual(m.counts[.cv], 1)
    }

    func testSelect() {
        let m = UniverseBrowserModel()
        let pkgs = sample()
        m.setCatalog(pkgs)
        m.select(pkgs[0])
        XCTAssertEqual(m.selected?.name, "basic-resume")
        XCTAssertNotNil(m.selectedVersion)
    }
}
