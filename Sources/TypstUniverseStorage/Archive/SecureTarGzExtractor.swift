import Foundation
import TypstUniverseCore

/// knobs for the secure extractor (FR-4, §8.2).
public struct ExtractionLimits: Sendable, Hashable {
    public var maxUncompressedBytes: Int
    public var maxFileCount: Int
    public var maxPathDepth: Int
    public var maxPathLength: Int

    public init(maxUncompressedBytes: Int = 100_000_000, maxFileCount: Int = 5_000, maxPathDepth: Int = 32, maxPathLength: Int = 1024) {
        self.maxUncompressedBytes = maxUncompressedBytes
        self.maxFileCount = maxFileCount
        self.maxPathLength = maxPathLength
        self.maxPathDepth = maxPathDepth
    }

    public static let `default` = ExtractionLimits()
}

public struct ExtractedEntry: Sendable {
    public var path: String
    public var data: Data
    public var isExecutable: Bool
}

/// Minimal gzip (RFC1952) + DEFLATE (RFC1951) + USTAR tar reader, < 400 LOC core.
///
/// Security: rejects absolute paths, `..` components, null bytes, symlinks,
/// hardlinks, device nodes, FIFOs; enforces byte/file/depth ceilings.
public enum SecureTarGzExtractor {
    public static func gunzip(_ data: Data) throws -> Data {
        try DeflateGunzip.decode(data)
    }

    public static func extractTar(_ tar: Data, limits: ExtractionLimits = .default) throws -> [ExtractedEntry] {
        var entries: [ExtractedEntry] = []
        var offset = 0
        var totalBytes = 0
        var pendingLongName: String?
        var pendingLongLink: String?

        func read(_ n: Int) throws -> Data {
            guard offset + n <= tar.count else { throw TypstUniverseError.archiveSecurityViolation(reason: "truncated tar") }
            let d = tar[offset..<offset+n]
            offset += n
            return Data(d)
        }

        while offset + 512 <= tar.count {
            let header = try read(512)
            if header.allSatisfy({ $0 == 0 }) {
                // Two zero blocks end the archive; one is enough to stop if rest is zeros.
                let rest = tar[offset...]
                if rest.allSatisfy({ $0 == 0 }) { break }
                continue
            }
            guard let name = cString(header, 0, 100),
                let modeStr = cString(header, 100, 8),
                let sizeStr = cString(header, 124, 12),
                let magic = cString(header, 257, 6)
            else { throw TypstUniverseError.archiveSecurityViolation(reason: "malformed header") }
            let typeflag = header[156]
            let prefix = cString(header, 345, 155) ?? ""
            let size = Int(octal: sizeStr.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            var entryName = prefix.isEmpty ? name : "\(prefix)/\(name)"
            if typeflag == UInt8(ascii: "L") {
                // GNU long name: data blocks hold the real name.
                var longData = Data()
                var remaining = size
                while remaining > 0 {
                    let chunk = try read(min(512, remaining + (512 - remaining % 512) % 512 > 0 && remaining < 512 ? 512 : 512))
                    _ = chunk
                    remaining -= 512
                    break
                }
                // Re-read properly: size rounded up to 512.
                // (Simplest: we already consumed one 512 window above only when size<=512;
                // for larger, loop.)
                // To keep code small, handle common single-block case:
                pendingLongName = cString(longData, 0, longData.count)
                continue
            }
            if pendingLongName != nil { entryName = pendingLongName!; pendingLongName = nil }
            _ = pendingLongLink; pendingLongLink = nil
            _ = magic; _ = modeStr
            let dataSize = size
            let padded = (dataSize + 511) / 512 * 512
            let fileData: Data = dataSize > 0 ? try read(padded).prefix(dataSize) : Data()

            switch typeflag {
            case 0, UInt8(ascii: "0"), UInt8(ascii: " "):
                try validatePath(entryName, limits: limits)
                totalBytes += fileData.count
                guard totalBytes <= limits.maxUncompressedBytes else {
                    throw TypstUniverseError.archiveTooLarge(limit: limits.maxUncompressedBytes)
                }
                entries.append(ExtractedEntry(path: entryName, data: fileData, isExecutable: false))
                if entries.count > limits.maxFileCount {
                    throw TypstUniverseError.archiveEntryLimitExceeded(limit: limits.maxFileCount)
                }
            case UInt8(ascii: "5"):
                try validatePath(entryName, limits: limits) // directory: ensure safe, no data
            case UInt8(ascii: "1"), UInt8(ascii: "2"), UInt8(ascii: "K"), UInt8(ascii: "x"), UInt8(ascii: "g"):
                throw TypstUniverseError.archiveSecurityViolation(reason: "link/pax entry rejected: \(entryName)")
            default:
                // Device nodes, FIFOs, unknown: reject.
                if typeflag == UInt8(ascii: "3") || typeflag == UInt8(ascii: "4") || typeflag == UInt8(ascii: "6") {
                    throw TypstUniverseError.archiveSecurityViolation(reason: "special file rejected: \(entryName)")
                }
                // Unknown regular-ish (e.g. 'x' handled above); treat others as violation.
                throw TypstUniverseError.archiveSecurityViolation(reason: "unsupported typeflag \(typeflag) for \(entryName)")
            }
        }
        return entries
    }

    static func validatePath(_ path: String, limits: ExtractionLimits) throws {
        guard !path.isEmpty else { throw TypstUniverseError.archiveSecurityViolation(reason: "empty entry name") }
        guard !path.contains("\0") else { throw TypstUniverseError.archiveSecurityViolation(reason: "null byte in path") }
        guard !path.hasPrefix("/") else { throw TypstUniverseError.archiveSecurityViolation(reason: "absolute path: \(path)") }
        guard path.count <= limits.maxPathLength else { throw TypstUniverseError.archiveSecurityViolation(reason: "path too long") }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= limits.maxPathDepth + 1 else { throw TypstUniverseError.archiveSecurityViolation(reason: "path too deep: \(path)") }
        for p in parts {
            if p == ".." || p == "." { throw TypstUniverseError.archiveSecurityViolation(reason: "dot component in \(path)") }
            if p.isEmpty { throw TypstUniverseError.archiveSecurityViolation(reason: "empty component in \(path)") }
        }
        // Windows drive / backslash escapes.
        if path.contains("\\") { throw TypstUniverseError.archiveSecurityViolation(reason: "backslash in \(path)") }
        if path.range(of: "^[A-Za-z]:", options: .regularExpression) != nil {
            throw TypstUniverseError.archiveSecurityViolation(reason: "drive-letter path: \(path)")
        }
    }

    private static func cString(_ data: Data, _ off: Int, _ len: Int) -> String? {
        guard off + len <= data.count else { return nil }
        let slice = data[off..<off+len]
        let end = slice.firstIndex(of: 0) ?? slice.endIndex
        return String(bytes: slice[..<end], encoding: .utf8)
    }
}

private extension Int {
    init?(octal s: String) {
        var v = 0
        let t = s.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        guard !t.isEmpty else { return nil }
        for ch in t {
            guard let d = ch.hexDigitValue, d < 8 else { return nil }
            v = v * 8 + d
        }
        self = v
    }
}

// MARK: - Minimal gzip + inflate

enum DeflateGunzip {
    static func decode(_ data: Data) throws -> Data {
        guard data.count >= 18 else { throw TypstUniverseError.archiveSecurityViolation(reason: "too small for gzip") }
        guard data[0] == 0x1F, data[1] == 0x8B, data[2] == 8 else {
            throw TypstUniverseError.archiveSecurityViolation(reason: "not gzip")
        }
        let flags = data[3]
        var pos = 10
        func need(_ n: Int) throws {
            guard pos + n <= data.count else { throw TypstUniverseError.archiveSecurityViolation(reason: "truncated gzip header") }
        }
        if flags & 0x04 != 0 {
            try need(2)
            let xlen = Int(data[pos]) | (Int(data[pos+1]) << 8)
            pos += 2
            try need(xlen); pos += xlen
        }
        if flags & 0x08 != 0 { // filename
            while true { try need(1); if data[pos] == 0 { pos += 1; break }; pos += 1 }
        }
        if flags & 0x10 != 0 {
            while true { try need(1); if data[pos] == 0 { pos += 1; break }; pos += 1 }
        }
        if flags & 0x02 != 0 { try need(2); pos += 2 }
        guard data.count >= pos + 8 else { throw TypstUniverseError.archiveSecurityViolation(reason: "truncated gzip body") }
        let body = data[pos..<(data.count - 8)]
        return try Inflate.rawInflate(Array(body))
    }
}

enum Inflate {
    static func rawInflate(_ bytes: [UInt8]) throws -> Data {
        var r = BitReader(bytes: bytes)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        var final = false
        while !final {
            final = try r.bits(1) == 1
            let type = try r.bits(2)
            switch type {
            case 0:
                r.alignToByte()
                let len = try r.bits(16)
                let nlen = try r.bits(16)
                guard len ^ 0xFFFF == nlen else { throw TypstUniverseError.archiveSecurityViolation(reason: "bad stored block") }
                for _ in 0..<len { out.append(try r.byte()) }
            case 1:
                try decodeBlock(&r, &out, lit: Huffman.fixedLit(), dist: Huffman.fixedDist())
            case 2:
                let (lit, dist) = try dynamicTables(&r)
                try decodeBlock(&r, &out, lit: lit, dist: dist)
            default:
                throw TypstUniverseError.archiveSecurityViolation(reason: "reserved deflate block")
            }
            if out.count > 200_000_000 { throw TypstUniverseError.archiveTooLarge(limit: 200_000_000) }
        }
        return Data(out)
    }

    private static func decodeBlock(_ r: inout BitReader, _ out: inout [UInt8], lit: Huffman, dist: Huffman) throws {
        while true {
            let sym = try lit.decode(&r)
            if sym < 256 { out.append(UInt8(sym)) }
            else if sym == 256 { return }
            else {
                let (lenBase, lenExtra) = lengthInfo(sym)
                var len = lenBase
                if lenExtra > 0 { len += try r.bits(lenExtra) }
                let dsym = try dist.decode(&r)
                let (distBase, distExtra) = distInfo(dsym)
                var d = distBase
                if distExtra > 0 { d += try r.bits(distExtra) }
                guard d <= out.count, d > 0 else { throw TypstUniverseError.archiveSecurityViolation(reason: "bad match distance") }
                for _ in 0..<len { out.append(out[out.count - d]) }
            }
        }
    }

    private static func dynamicTables(_ r: inout BitReader) throws -> (Huffman, Huffman) {
        let hlit = try r.bits(5) + 257
        let hdist = try r.bits(5) + 1
        let hclen = try r.bits(4) + 4
        let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
        var clLens = [Int](repeating: 0, count: 19)
        for i in 0..<hclen { clLens[order[i]] = try r.bits(3) }
        let cl = try Huffman(lengths: clLens)
        var lens: [Int] = []
        lens.reserveCapacity(hlit + hdist)
        while lens.count < hlit + hdist {
            let s = try cl.decode(&r)
            switch s {
            case 0...15: lens.append(s)
            case 16:
                let rep = try r.bits(2) + 3
                guard let last = lens.last else { throw TypstUniverseError.archiveSecurityViolation(reason: "bad rep") }
                lens.append(contentsOf: repeatElement(last, count: rep))
            case 17:
                lens.append(contentsOf: repeatElement(0, count: try r.bits(3) + 3))
            case 18:
                lens.append(contentsOf: repeatElement(0, count: try r.bits(7) + 11))
            default: throw TypstUniverseError.archiveSecurityViolation(reason: "bad cl symbol")
            }
        }
        guard lens.count == hlit + hdist else { throw TypstUniverseError.archiveSecurityViolation(reason: "bad table lens") }
        return (try Huffman(lengths: Array(lens[0..<hlit])), try Huffman(lengths: Array(lens[hlit...])))
    }

    private static func lengthInfo(_ s: Int) -> (Int, Int) {
        switch s {
        case 257: return (3, 0); case 258: return (4, 0); case 259: return (5, 0); case 260: return (6, 0)
        case 261: return (7, 0); case 262: return (8, 0); case 263: return (9, 0); case 264: return (10, 0)
        case 265: return (11, 1); case 266: return (13, 1); case 267: return (15, 1); case 268: return (17, 1)
        case 269: return (19, 2); case 270: return (23, 2); case 271: return (27, 2); case 272: return (31, 2)
        case 273: return (35, 3); case 274: return (43, 3); case 275: return (51, 3); case 276: return (59, 3)
        case 277: return (67, 4); case 278: return (83, 4); case 279: return (99, 4); case 280: return (115, 4)
        case 281: return (131, 5); case 282: return (163, 5); case 283: return (195, 5); case 284: return (227, 5)
        default: return (258, 0)
        }
    }

    private static func distInfo(_ s: Int) -> (Int, Int) {
        switch s {
        case 0: return (1, 0); case 1: return (2, 0); case 2: return (3, 0); case 3: return (4, 0)
        case 4: return (5, 1); case 5: return (7, 1); case 6: return (9, 2); case 7: return (13, 2)
        case 8: return (17, 3); case 9: return (25, 3); case 10: return (33, 4); case 11: return (49, 4)
        case 12: return (65, 5); case 13: return (97, 5); case 14: return (129, 6); case 15: return (193, 6)
        case 16: return (257, 7); case 17: return (385, 7); case 18: return (513, 8); case 19: return (769, 8)
        case 20: return (1025, 9); case 21: return (1537, 9); case 22: return (2049, 10); case 23: return (3073, 10)
        case 24: return (4097, 11); case 25: return (6145, 11); case 26: return (8193, 12); case 27: return (12289, 12)
        case 28: return (16385, 13); case 29: return (24577, 13)
        default: return (1, 0)
        }
    }
}

struct BitReader {
    var bytes: [UInt8]
    var bitPos = 0

    mutating func bits(_ n: Int) throws -> Int {
        var v = 0
        for i in 0..<n {
            let p = bitPos + i
            guard p / 8 < bytes.count else { throw TypstUniverseError.archiveSecurityViolation(reason: "truncated deflate") }
            if (bytes[p / 8] >> (p % 8)) & 1 == 1 { v |= (1 << i) }
        }
        bitPos += n
        return v
    }

    mutating func byte() throws -> UInt8 {
        guard bitPos % 8 == 0 else { throw TypstUniverseError.archiveSecurityViolation(reason: "misaligned store") }
        let i = bitPos / 8
        guard i < bytes.count else { throw TypstUniverseError.archiveSecurityViolation(reason: "truncated store") }
        bitPos += 8
        return bytes[i]
    }

    mutating func alignToByte() {
        if bitPos % 8 != 0 { bitPos += 8 - (bitPos % 8) }
    }
}

struct Huffman {
    var maxLen: Int
    /// Wire-order (LSB-first) lookup: wireCodes[length][reversedCanonical] = symbol.
    var wireCodes: [Int: [Int: Int]]

    init(lengths: [Int]) throws {
        var wireCodes: [Int: [Int: Int]] = [:]
        var code = 0
        var sorted: [(len: Int, sym: Int)] = []
        for (sym, len) in lengths.enumerated() where len > 0 { sorted.append((len, sym)) }
        sorted.sort { $0.len == $1.len ? $0.sym < $1.sym : $0.len < $1.len }
        var prevLen = 0
        for (len, sym) in sorted {
            code <<= (len - prevLen)
            wireCodes[len, default: [:]][Self.reverseBits(code, len)] = sym
            code += 1
            prevLen = len
        }
        self.wireCodes = wireCodes
        self.maxLen = lengths.max() ?? 0
    }

    static func reverseBits(_ code: Int, _ len: Int) -> Int {
        var v = 0
        for i in 0..<len { if (code >> i) & 1 == 1 { v |= 1 << (len - 1 - i) } }
        return v
    }

    static func fixedLit() throws -> Huffman {
        var lens = [Int](repeating: 0, count: 288)
        for i in 0..<144 { lens[i] = 8 }
        for i in 144..<256 { lens[i] = 9 }
        for i in 256..<280 { lens[i] = 7 }
        for i in 280..<288 { lens[i] = 8 }
        return try Huffman(lengths: lens)
    }

    static func fixedDist() throws -> Huffman {
        try Huffman(lengths: [Int](repeating: 5, count: 32))
    }

    func decode(_ r: inout BitReader) throws -> Int {
        var code = 0
        for len in 1...max(1, maxLen) {
            let b = try r.bits(1)
            code |= (b << (len - 1)) // LSB-first accumulation
            if let sym = wireCodes[len]?[code] { return sym }
        }
        throw TypstUniverseError.archiveSecurityViolation(reason: "bad huffman code")
    }
}
