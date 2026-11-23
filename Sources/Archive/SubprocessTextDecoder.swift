import CoreFoundation
import Foundation

/// Decodes raw bytes from a subprocess into text **without dropping data**.
///
/// 7-Zip can emit filenames that are not valid UTF-8 (legacy ZIPs created on
/// Windows in GBK/GB2312). Naively decoding chunk-by-chunk with `.utf8` both drops
/// such bytes and corrupts multi-byte characters that straddle a chunk boundary.
/// We buffer raw bytes and decode with a fallback chain:
///   1. UTF-8 (the common case, and what `-sccUTF-8` asks for)
///   2. GB18030 (superset of GBK/GB2312) for legacy Chinese names
///   3. Lossy UTF-8 replacement — never returns nil, never loses the line
enum SubprocessTextDecoder {
    static func decode(_ data: Data) -> String {
        guard !data.isEmpty else { return "" }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let gb = gb18030, let text = String(data: data, encoding: gb) { return text }
        return String(decoding: data, as: UTF8.self)
    }

    static var gb18030: String.Encoding? {
        let raw = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        guard raw != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: raw)
    }
}
