import CoreFoundation
import Foundation

/// Minimal ZIP central-directory reader used to recover **original file names**
/// when 7-Zip's listing renders legacy (GBK/Big5) names as `?`. 7-Zip's `-mcp`
/// switch is a compression/extraction option, so listing cannot be told the code
/// page; parsing the central directory ourselves is the reliable fix.
enum ZipCentralDirectoryReader {
    struct Entry: Equatable, Sendable {
        let path: String
        let uncompressedSize: Int64
        let compressedSize: Int64
        let isDirectory: Bool
    }

    enum Failure: Error { case notZip, badStructure }

    static func entries(inFileAt url: URL) -> [Entry]? {
        guard let data = try? Data(contentsOf: url), data.count > 22 else { return nil }
        return entries(in: data)
    }

    static func entries(in data: Data) -> [Entry]? {
        guard let eocd = findEOCD(in: data) else { return nil }
        let total = Int(readUInt16(data, eocd + 10))
        let cdOffset = Int(readUInt32(data, eocd + 16))
        var cursor = cdOffset
        var result: [Entry] = []
        for _ in 0..<total {
            guard cursor + 46 <= data.count, readUInt32(data, cursor) == 0x0201_4B50 else { break }
            let flags = readUInt16(data, cursor + 8)
            let compressed = Int64(readUInt32(data, cursor + 20))
            let uncompressed = Int64(readUInt32(data, cursor + 24))
            let nameLen = Int(readUInt16(data, cursor + 28))
            let extraLen = Int(readUInt16(data, cursor + 30))
            let commentLen = Int(readUInt16(data, cursor + 32))
            let nameStart = cursor + 46
            guard nameStart + nameLen <= data.count else { break }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLen))
            let isUTF8 = (flags & 0x0800) != 0
            let path = decodeName(nameData, isUTF8: isUTF8)
            result.append(Entry(
                path: path,
                uncompressedSize: uncompressed,
                compressedSize: compressed,
                isDirectory: path.hasSuffix("/")
            ))
            cursor = nameStart + nameLen + extraLen + commentLen
        }
        return result.isEmpty ? nil : result
    }

    private static func findEOCD(in data: Data) -> Int? {
        let sig: UInt32 = 0x0605_4B50
        var i = data.count - 22
        let lowerBound = max(0, data.count - 22 - 65_535)
        while i >= lowerBound {
            if i + 4 <= data.count, readUInt32(data, i) == sig { return i }
            i -= 1
        }
        return nil
    }

    private static func decodeName(_ bytes: Data, isUTF8: Bool) -> String {
        if isUTF8, let s = String(data: bytes, encoding: .utf8) { return s }
        if let s = String(data: bytes, encoding: .utf8) { return s }
        for encoding in [gb18030, big5].compactMap({ $0 }) {
            if let s = String(data: bytes, encoding: encoding) { return s }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static var gb18030: String.Encoding? {
        let raw = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return raw == kCFStringEncodingInvalidId ? nil : String.Encoding(rawValue: raw)
    }
    static var big5: String.Encoding? {
        let raw = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))
        return raw == kCFStringEncodingInvalidId ? nil : String.Encoding(rawValue: raw)
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }
    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }
}
