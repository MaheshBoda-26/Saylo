import Foundation
import Testing
@testable import SayloCore

@Test func chunkerKeepsShortAudioWhole() {
    let pcm = [Float](repeating: 0.1, count: 16_000 * 10)
    #expect(AudioChunker.chunk(pcm).count == 1)
}

@Test func chunkerSplitsAtQuietPointWithinLimit() {
    var pcm = [Float](repeating: 0.5, count: 16_000 * 50)
    for i in (16_000 * 27)..<(16_000 * 27 + 4_000) { pcm[i] = 0 }  // silence at ~27 s
    let chunks = AudioChunker.chunk(pcm)
    #expect(chunks.count == 2)
    #expect(chunks.allSatisfy { $0.count <= 16_000 * 30 })
    #expect(chunks.reduce(0) { $0 + $1.count } == pcm.count)
    #expect(abs(chunks[0].count - 16_000 * 27) < 4_000)
}

@Test func postProcessorCleansText() {
    let p = TextPostProcessor(replacements: ["salo": "Saylo"])
    #expect(p.process("  hello from salo ") == "Hello from Saylo.")
    #expect(p.process("is it done?") == "Is it done?")
    #expect(p.process("   ") == "")
}

@Test func postProcessorRemovesFillers() {
    let p = TextPostProcessor()
    #expect(p.process("Um, I went uh to the store") == "I went to the store.")
    #expect(p.process("uhh let me think hmm yeah") == "Let me think yeah.")
    #expect(p.process("it is, err, finished") == "It is, finished.")
    #expect(p.process("UMM WHAT") == "WHAT.")
    #expect(p.process("uh um hmm") == "")
    // Real words containing filler spellings must survive.
    #expect(p.process("the drummer heard ahem") == "The drummer heard ahem.")
    // Affirmations are meaning, not filler.
    #expect(p.process("uh-huh that works") == "Uh-huh that works.")
    // Opt-out keeps the old behavior.
    #expect(TextPostProcessor(removingFillers: false).process("um hi") == "Um hi.")
}

@Test func parsesEngineJSON() throws {
    let t = try WhistleEngine.parse(#"{"text":"hi","language":"en","ttft_ms":12.5,"decode_tps":900}"#)
    #expect(t == Transcript(text: "hi", language: "en", ttftMs: 12.5))
}

@Test func transcribesRealClip() async throws {
    let model = URL(fileURLWithPath: "vendor/whistle.cact")
    let clip = URL(fileURLWithPath: "vendor/test.wav")
    guard FileManager.default.fileExists(atPath: model.path),
          FileManager.default.fileExists(atPath: clip.path) else { return }
    let engine = try WhistleEngine(modelURL: model)
    let t = try await engine.transcribe(try AudioRecorder.load(url: clip), keywords: ["Saylo"])
    #expect(t.language == "en")
    #expect(t.text.lowercased().contains("dictation test"))

    let silence = try await engine.transcribe([Float](repeating: 0, count: 16_000 * 2))
    #expect(silence.text.isEmpty)
}
