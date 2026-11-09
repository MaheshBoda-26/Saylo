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
    case outputTooLong(Int)

    public var description: String {
        switch self {
        case .modelNotFound(let p): return "Whistle model not found at \(p)"
        case .engine(let m): return "Whistle engine error: \(m)"
        case .outputTooLong(let capacity): return "Whistle output exceeded the \(capacity)-byte buffer"
        }
    }
}

/// Swift wrapper over the Whistle C engine. The engine holds one process-global,
/// non-thread-safe speech model, so all access is serialized through this actor.
public actor WhistleEngine {
    public static let sampleRate = 16_000

    /// Output buffer for one transcription. 30 s of speech is a few kilobytes of
    /// JSON; 64 KB leaves two orders of magnitude of headroom.
    private static let outputCapacity = 64 * 1024

    public init(modelURL: URL) throws {
        let data: Data
        do {
            data = try Data(contentsOf: modelURL)
        } catch {
            throw WhistleError.modelNotFound(modelURL.path)
        }
        guard !data.isEmpty else { throw WhistleError.modelNotFound(modelURL.path) }

        let rc = data.withUnsafeBytes { buf in
            needle_load(buf.bindMemory(to: UInt8.self).baseAddress, UInt64(buf.count))
        }
        if rc < 0 { throw WhistleError.engine(Self.lastError()) }
    }

    /// Warms up the engine pipeline by transcribing a short slice of silence.
    public func warmUp() throws {
        _ = try transcribeChunk([Float](repeating: 0, count: 1600), language: "en", keywords: [])
    }

    /// Transcribes 16 kHz mono PCM of any length; clips over 30 s are split at quiet points.
    public func transcribe(_ pcm: [Float], language: String? = "en", keywords: [String] = []) throws -> Transcript {
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

        var out = [CChar](repeating: 0, count: Self.outputCapacity)
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

        // The engine writes a NUL-terminated string, but never trust it to have
        // terminated inside the buffer: read up to the terminator, and treat a
        // full buffer as a failure rather than reading past the allocation.
        let terminator = out.firstIndex(of: 0) ?? out.count
        guard terminator < out.count else { throw WhistleError.outputTooLong(out.count) }

        let json = String(decoding: out[..<terminator].map { UInt8(bitPattern: $0) }, as: UTF8.self)
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
