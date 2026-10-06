import CNeedle
import Foundation

public struct Transcript: Sendable, Equatable {
    public let text: String
    public let language: String
    public let ttftMs: Double
}

public enum WhistleError: Error, CustomStringConvertible {
    case modelNotFound(String)
    case engine(String)

    public var description: String {
        switch self {
        case .modelNotFound(let p): return "Whistle model not found at \(p)"
        case .engine(let m): return "Whistle engine error: \(m)"
        }
    }
}

/// Swift wrapper over the Whistle C engine. The engine holds one process-global,
/// non-thread-safe speech model, so all access is serialized through this actor.
public actor WhistleEngine {
    public static let sampleRate = 16_000
    public static let maxSamples = 30 * sampleRate

    public init(modelURL: URL) throws {
        guard let data = try? Data(contentsOf: modelURL) else {
            throw WhistleError.modelNotFound(modelURL.path)
        }
        let rc = data.withUnsafeBytes { buf in
            needle_load(buf.bindMemory(to: UInt8.self).baseAddress, UInt64(buf.count))
        }
        if rc < 0 { throw WhistleError.engine(Self.lastError()) }
    }

    /// Warms up the engine pipeline by transcribing a short slice of silence.
    public func warmUp() throws {
        _ = try transcribeChunk([Float](repeating: 0, count: 1600), language: nil, keywords: [])
    }

    /// Transcribes 16 kHz mono PCM of any length; clips over 30 s are split at quiet points.
    public func transcribe(_ pcm: [Float], language: String? = nil, keywords: [String] = []) throws -> Transcript {
        var texts: [String] = []
        var lang = ""
        var ttft = 0.0
        for (i, chunk) in AudioChunker.chunk(pcm).enumerated() {
            let t = try transcribeChunk(chunk, language: language, keywords: keywords)
            if !t.text.isEmpty { texts.append(t.text) }
            if lang.isEmpty { lang = t.language }
            if i == 0 { ttft = t.ttftMs }
        }
        return Transcript(text: texts.joined(separator: " "), language: lang, ttftMs: ttft)
    }

    private func transcribeChunk(_ pcm: [Float], language: String?, keywords: [String]) throws -> Transcript {
        guard !pcm.isEmpty else { return Transcript(text: "", language: "", ttftMs: 0) }
        var out = [CChar](repeating: 0, count: 64 * 1024)
        let kw = keywords.isEmpty ? nil : keywords.joined(separator: "\n")
        let rc = pcm.withUnsafeBufferPointer { p in
            out.withUnsafeMutableBufferPointer { o in
                withOptionalCString(language) { l in
                    withOptionalCString(kw) { k in
                        needle_transcribe(p.baseAddress, Int32(p.count), l, k, 0, o.baseAddress, Int32(o.count))
                    }
                }
            }
        }
        if rc < 0 { throw WhistleError.engine(Self.lastError()) }
        let json = out.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        return try Self.parse(json)
    }

    static func parse(_ json: String) throws -> Transcript {
        struct Raw: Decodable { let text: String; let language: String; let ttft_ms: Double }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: Data(json.utf8)) else {
            throw WhistleError.engine("unparseable output: \(json)")
        }
        return Transcript(text: raw.text, language: raw.language, ttftMs: raw.ttft_ms)
    }

    private static func lastError() -> String {
        needle_last_error().map { String(cString: $0) } ?? "unknown"
    }
}

private func withOptionalCString<R>(_ s: String?, _ body: (UnsafePointer<CChar>?) -> R) -> R {
    guard let s else { return body(nil) }
    return s.withCString(body)
}
