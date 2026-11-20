import Foundation
import Testing
@testable import TypstUniverseCore
@testable import TypstUniverseStorage

func makeTarEntry(name: String, data: Data, typeflag: UInt8 = UInt8(ascii: "0")) -> Data {
    var header = [UInt8](repeating: 0, count: 512)
    func write(_ s: String, offset: Int, length: Int) {
        let bytes = Array(s.utf8)
        for (i, b) in bytes.prefix(length).enumerated() { header[offset + i] = b }
    }
    write(name, offset: 0, length: 100)
    write("0000777", offset: 100, length: 8)
    write("0000000", offset: 108, length: 8)
    write("0000000", offset: 116, length: 8)
    write(String(format: "%011o", data.count), offset: 124, length: 12)
    write("00000000000", offset: 136, length: 12)
    header[156] = typeflag
    write("ustar", offset: 257, length: 6)
    write("00", offset: 263, length: 2)
    // checksum
    for i in 148..<156 { header[i] = UInt8(ascii: " ") }
    let sum = header.reduce(0) { $0 + Int($1) }
    write(String(format: "%06o\0 ", sum), offset: 148, length: 8)
    var out = Data(header)
    out.append(data)
    let pad = (512 - data.count % 512) % 512
    out.append(Data(repeating: 0, count: pad))
    return out
}

func makeTar(_ entries: [(String, Data, UInt8)]) -> Data {
    var d = Data()
    for (n, data, t) in entries { d.append(makeTarEntry(name: n, data: data, typeflag: t)) }
    d.append(Data(repeating: 0, count: 1024))
    return d
}

@Suite("SecureTar")
struct SecureTarTests {
    @Test func validTar() throws {
        let tar = makeTar([("pkg/lib.typ", Data("hello".utf8), UInt8(ascii: "0")), ("pkg/", Data(), UInt8(ascii: "5"))])
        let entries = try SecureTarGzExtractor.extractTar(tar)
        #expect(entries.count == 1)
        #expect(entries[0].path == "pkg/lib.typ")
    }

    @Test func rejectsTraversal() {
        let tar = makeTar([("../../etc/passwd", Data("x".utf8), UInt8(ascii: "0"))])
        #expect(throws: TypstUniverseError.self) { try SecureTarGzExtractor.extractTar(tar) }
    }

    @Test func skipsDotRootEntry() throws {
        // Registry tarballs (e.g. benplate 0.2.0) start with a bare `.`
        // root directory entry: it must not abort the whole archive.
        let five: UInt8 = UInt8(ascii: "5")
        let tar = makeTar([(".", Data(), five), ("pkg/lib.typ", Data("hello".utf8), UInt8(ascii: "0"))])
        let entries = try SecureTarGzExtractor.extractTar(tar)
        #expect(entries.count == 1)
        #expect(entries[0].path == "pkg/lib.typ")
    }

    @Test func normalizesDotSlashPrefix() throws {
        let tar = makeTar([("./pkg/lib.typ", Data("hello".utf8), UInt8(ascii: "0"))])
        let entries = try SecureTarGzExtractor.extractTar(tar)
        #expect(entries.map(\.path) == ["pkg/lib.typ"])
    }

    @Test func collapsesInnerDotDot() throws {
        let tar = makeTar([("pkg/sub/../lib.typ", Data("hello".utf8), UInt8(ascii: "0"))])
        let entries = try SecureTarGzExtractor.extractTar(tar)
        #expect(entries.map(\.path) == ["pkg/lib.typ"])
    }

    @Test func rejectsDotDotEscapeMidPath() {
        let tar = makeTar([("pkg/../../etc/passwd", Data("x".utf8), UInt8(ascii: "0"))])
        #expect(throws: TypstUniverseError.self) { try SecureTarGzExtractor.extractTar(tar) }
    }

    @Test func rejectsAbsolute() {
        let tar = makeTar([("/etc/passwd", Data("x".utf8), UInt8(ascii: "0"))])
        #expect(throws: TypstUniverseError.self) { try SecureTarGzExtractor.extractTar(tar) }
    }

    @Test func rejectsSymlink() {
        let tar = makeTar([("pkg/link", Data("target".utf8), UInt8(ascii: "2"))])
        #expect(throws: TypstUniverseError.self) { try SecureTarGzExtractor.extractTar(tar) }
    }

    @Test func rejectsDeepPath() {
        let deep = Array(repeating: "a", count: 40).joined(separator: "/") + "/f.typ"
        let tar = makeTar([(deep, Data("x".utf8), UInt8(ascii: "0"))])
        #expect(throws: TypstUniverseError.self) { try SecureTarGzExtractor.extractTar(tar) }
    }

    @Test func rejectsBadGzip() {
        #expect(throws: TypstUniverseError.self) { try SecureTarGzExtractor.gunzip(Data("nope".utf8)) }
    }

    @Test func gunzipStoredBlock() throws {
        // Minimal gzip with stored (uncompressed) "Hi": header + deflate + crc/size.
        var raw: [UInt8] = [0x1F, 0x8B, 8, 0, 0, 0, 0, 0, 0, 0xFF]
        // deflate stored block: BFINAL=1, BTYPE=00, LEN=2, NLEN, "Hi"
        raw += [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x48, 0x69]
        // crc32 + isize (decoder ignores content, needs 8 bytes)
        raw += [0, 0, 0, 0, 2, 0, 0, 0]
        let out = try SecureTarGzExtractor.gunzip(Data(raw))
        #expect(out == Data("Hi".utf8))
    }
}

@Suite("Scaffolder")
struct ScaffolderTests {
    @Test func scaffoldCopiesTemplate() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "tusk-test-\(UUID().uuidString)")
        let pkgDir = root.appending(path: "preview/demo/1.0.0", directoryHint: .isDirectory)
        let templateDir = pkgDir.appending(path: "template", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true)
        try "[package]\nname=\"demo\"\nversion=\"1.0.0\"\nentrypoint=\"lib.typ\"\n[template]\npath=\"template\"\nentrypoint=\"main.typ\"\n".write(to: pkgDir.appending(path: "typst.toml"), atomically: true, encoding: .utf8)
        try "hello".write(to: templateDir.appending(path: "main.typ"), atomically: true, encoding: .utf8)
        let cache = PackageCacheManager(config: .init(storageRoot: root), registry: OfficialUniverseRegistry())
        // Mark installed by the files we just created (cache root == root).
        let scaffolder = TemplateScaffolder(cache: cache)
        let spec = PackageSpec(namespace: .preview, name: "demo", version: SemanticVersion(1, 0, 0))
        let dest = root.appending(path: "out", directoryHint: .isDirectory)
        let project = try await scaffolder.scaffold(spec, to: dest)
        #expect(project.files == ["main.typ"])
        #expect(FileManager.default.fileExists(atPath: dest.appending(path: "main.typ").path))
        try? FileManager.default.removeItem(at: root)
    }
}
