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

// MARK: - Silence rejection

/// Room tone at roughly -52 dBFS, the level a quiet room produces with no speech.
private func roomTone(seconds: Double, rms: Float = 0.0025, seed: UInt64 = 42) -> [Float] {
    var rng = SplitMix64(seed: seed)
    return (0..<Int(seconds * 16_000)).map { _ in (Float(rng.next() % 2_000) / 1_000 - 1) * rms }
}

private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test func silenceIsNotSpeech() {
    #expect(!SpeechActivity.containsSpeech([Float](repeating: 0, count: 16_000 * 2)))
    #expect(!SpeechActivity.containsSpeech(roomTone(seconds: 2)))
    #expect(!SpeechActivity.containsSpeech([]))
}

@Test func quietSpeechIsStillSpeech() {
    // Quiet speech at about -34 dBFS must survive the gate; rejecting it would
    // break the low-volume dictation this normalization exists to support.
    var pcm = roomTone(seconds: 2)
    for i in 6_000..<10_000 { pcm[i] = 0.02 }
    #expect(SpeechActivity.containsSpeech(pcm))
}

/// A short utterance inside a long silent clip still registers: whole-clip RMS
/// would average this below any threshold that admits background noise.
@Test func briefSpeechInLongClipIsDetected() {
    var pcm = roomTone(seconds: 20)
    for i in 100_000..<104_000 { pcm[i] = 0.02 }
    #expect(SpeechActivity.peakWindowRMS(pcm) > SpeechActivity.peakWindowRMS(roomTone(seconds: 20)))
    #expect(SpeechActivity.containsSpeech(pcm))
}

/// The regression this guards: normalizing each capture buffer separately lifted
/// silence to speech level, so a recording with nothing but room tone reached the
/// model and came back as an invented phrase.
@Test func normalizingPerBufferUsedToAmplifySilence() {
    let noise = roomTone(seconds: 1)
    var once = noise
    SpeechActivity.normalize(&once, reference: SpeechActivity.peakWindowRMS(once), maxGain: 10)
    #expect(!SpeechActivity.containsSpeech(once), "normalizing must never lift room tone over the gate")

    // Same audio, boosted per 1024-frame buffer the way the tap used to do.
    var perBuffer = noise
    var i = 0
    while i < perBuffer.count {
        let end = min(i + 341, perBuffer.count)
        let slice = Array(perBuffer[i..<end])
        var s = Array(slice)
        let g = min(SpeechActivity.targetRMS / max(SpeechActivity.rms(s), 0.0001), 10)
        for k in s.indices { s[k] *= g }
        perBuffer.replaceSubrange(i..<end, with: s)
        i = end
    }
    #expect(SpeechActivity.peakWindowRMS(perBuffer) >= SpeechActivity.speechThreshold,
            "per-buffer gain is what pushed room tone over the gate")
}

/// Normalizing once against the loudest window brings quiet speech up without
/// lifting the surrounding silence with it.
@Test func wholeClipNormalizationScalesSpeechOnly() {
    var pcm = roomTone(seconds: 3)
    for i in 8_000..<12_000 { pcm[i] = 0.02 }
    let noiseBefore = SpeechActivity.peakWindowRMS(roomTone(seconds: 3))
    SpeechActivity.normalize(&pcm, reference: SpeechActivity.peakWindowRMS(pcm))
    let window = SpeechActivity.peakWindowRMS(Array(pcm[0..<8_000]))
    #expect(window > noiseBefore)
    #expect(SpeechActivity.containsSpeech(pcm))
}

@Test func meterReadsSilenceAsSilence() {
    #expect(SpeechActivity.meterLevel(rms: 0) == 0)
    #expect(SpeechActivity.meterLevel(rms: 0.0025) < 0.3, "room tone must not look like a live signal")
    #expect(SpeechActivity.meterLevel(rms: 0.1) > 0.6)
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

/// The other half of the gate: real speech must still clear it. `silenceIsNotSpeech`
/// only proves noise is rejected; if the threshold sat above a normal recording the
/// app would silently drop real dictation.
@Test func realSpeechClearsTheGate() throws {
    let clip = URL(fileURLWithPath: "vendor/test.wav")
    guard FileManager.default.fileExists(atPath: clip.path) else { return }
    let pcm = try AudioRecorder.load(url: clip)
    #expect(SpeechActivity.containsSpeech(pcm))
    #expect(SpeechActivity.peakWindowRMS(pcm) > SpeechActivity.speechThreshold)
}
