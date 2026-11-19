import Foundation
import Testing
@testable import TypstUniverseCore

@Suite("SemanticVersion")
struct SemanticVersionTests {
    @Test func parsesBasic() {
        #expect(SemanticVersion("0.14.0") == SemanticVersion(0, 14, 0))
        #expect(SemanticVersion("1.2.3-alpha.1")?.prerelease == "alpha.1")
        #expect(SemanticVersion("01.2.3") == nil) // leading zero rejected
        #expect(SemanticVersion("not-a-version") == nil)
    }

    @Test func ordering() {
        #expect(SemanticVersion(0, 10, 0) > SemanticVersion(0, 2, 0))
        #expect(SemanticVersion(1, 0, 0, prerelease: "alpha") < SemanticVersion(1, 0, 0))
        #expect(SemanticVersion(1, 0, 0, prerelease: "alpha") < SemanticVersion(1, 0, 0, prerelease: "beta"))
        #expect(SemanticVersion(1, 0, 0, prerelease: "1") < SemanticVersion(1, 0, 0, prerelease: "alpha"))
    }

    @Test func roundTrip() throws {
        let v = SemanticVersion(0, 3, 1)
        let data = try JSONEncoder().encode(v)
        #expect(String(data: data, encoding: .utf8) == "\"0.3.1\"")
    }
}

@Suite("IndexDecoder")
struct IndexDecoderTests {
    @Test func groupsAndSorts() throws {
        let json = """
        [
          {"name":"cetz","version":"0.2.0","description":"Diagrams","authors":["A"],"categories":["visualization"],"keywords":[]},
          {"name":"cetz","version":"0.3.1","description":"Diagrams v2","authors":["A"],"categories":["visualization"],"keywords":[]},
          {"name":"basic-resume","version":"0.2.8","description":"Resume","authors":["B <b@x.com>"],"categories":["cv"],"template":{"path":"template","entrypoint":"main.typ"}}
        ]
        """.data(using: .utf8)!
        let pkgs = try IndexDecoder.decode(json)
        #expect(pkgs.count == 2)
        let cetz = pkgs.first { $0.name == "cetz" }!
        #expect(cetz.latestVersion?.version == SemanticVersion(0, 3, 1))
        #expect(cetz.versions.count == 2)
        let resume = pkgs.first { $0.name == "basic-resume" }!
        #expect(resume.isTemplate)
        #expect(!cetz.isTemplate)
    }

    @Test func lenientUnknowns() throws {
        let json = """
        [{"name":"future","version":"1.0.0","futureField":123,"categories":["brand-new-cat"],"disciplines":["xenolinguistics"],"authors":[{}],"updated_at":"not-a-date"}]
        """.data(using: .utf8)!
        let pkgs = try IndexDecoder.decode(json)
        #expect(pkgs.count == 1)
        #expect(pkgs[0].latestVersion?.categories.first?.rawValue == "brand-new-cat")
        #expect(pkgs[0].latestVersion?.updatedAt == nil)
    }
}

@Suite("Search")
struct SearchTests {
    private func sample() -> [UniversePackage] {
        let a = UniversePackage(namespace: .preview, name: "basic-resume", versions: [
            PackageVersion(name: "basic-resume", version: SemanticVersion(0, 2, 8), description: "Simple resume template", authors: [PackageAuthor(name: "Jane")], categories: [.cv], disciplines: [.business], compilerVersion: SemanticVersion(0, 10, 0), updatedAt: Date(timeIntervalSince1970: 1_710_000_000), releasedAt: Date(timeIntervalSince1970: 1_700_000_000), template: TemplateInfo(path: "template", entrypoint: "main.typ"))
        ])
        let b = UniversePackage(namespace: .preview, name: "cetz", versions: [
            PackageVersion(name: "cetz", version: SemanticVersion(0, 3, 1), description: "Drawing library", keywords: ["plot", "diagram"], categories: [.visualization], compilerVersion: SemanticVersion(0, 11, 0), updatedAt: Date(timeIntervalSince1970: 1_720_000_000), releasedAt: Date(timeIntervalSince1970: 1_690_000_000))
        ])
        return [a, b]
    }

    @Test func exactNameRanksFirst() {
        let r = UniverseSearchEngine().search(sample(), query: UniverseQuery(text: "cetz"))
        #expect(r.first?.name == "cetz")
    }

    @Test func kindFilter() {
        let r = UniverseSearchEngine().search(sample(), query: UniverseQuery(kind: .templatesOnly))
        #expect(r.count == 1 && r[0].name == "basic-resume")
    }

    @Test func categoryAndCompiler() {
        let engine = UniverseSearchEngine()
        let cat = engine.search(sample(), query: UniverseQuery(categories: [.cv]))
        #expect(cat.count == 1)
        let compat = engine.search(sample(), query: UniverseQuery(compatibleWithCompiler: SemanticVersion(0, 10, 0)))
        #expect(compat.count == 1 && compat[0].name == "basic-resume")
    }

    @Test func counts() {
        #expect(UniverseSearchEngine().categoryCounts(sample())[.cv] == 1)
    }
}

@Suite("TOML")
struct TomlTests {
    @Test func parsesManifest() throws {
        let toml = """
        [package]
        name = "basic-resume"
        version = "0.2.8"
        entrypoint = "lib.typ"
        authors = ["Jane"]
        license = "MIT"
        categories = ["cv"]
        compiler = "0.10.0"

        [template]
        path = "template"
        entrypoint = "main.typ"
        """
        let m = try TypstTomlParser.parseManifest(toml)
        #expect(m.package.name == "basic-resume")
        #expect(m.template?.path == "template")
        #expect(m.package.compiler == SemanticVersion(0, 10, 0))
    }

    @Test func missingTemplateIsNil() throws {
        let toml = "[package]\nname = \"x\"\nversion = \"1.0.0\"\nentrypoint = \"lib.typ\"\n"
        #expect(try TypstTomlParser.parseManifest(toml).template == nil)
    }
}

@Suite("Snippets")
struct SnippetTests {
    @Test func importAndInit() {
        let pkg = UniversePackage(namespace: .preview, name: "cetz", versions: [
            PackageVersion(name: "cetz", version: SemanticVersion(0, 3, 1))
        ])
        #expect(pkg.importSnippet() == "#import \"@preview/cetz:0.3.1\": *")
        #expect(pkg.initCommand() == "typst init @preview/cetz:0.3.1")
    }
}
