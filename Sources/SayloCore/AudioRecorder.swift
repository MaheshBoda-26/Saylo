@preconcurrency import AVFoundation
import Foundation

/// Captures the default microphone and converts it to 16 kHz mono Float32 for Whistle.
public final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var buffer: [Float] = []
    private var _level: Float = 0
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                       channels: 1, interleaved: false)!

    public init() {}

    /// Current RMS level (0...1), for UI meters.
    public var level: Float { lock.withLock { _level } }

    public func start() throws {
        lock.withLock { buffer.removeAll(keepingCapacity: true) }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: format, to: target) else {
            throw NSError(domain: "Saylo", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio converter"])
        }
        let ratio = target.sampleRate / format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] pcm, _ in
            guard let self else { return }
            let cap = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 32
            guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: cap) else { return }
            var fed = false
            converter.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return pcm
            }
            guard let ch = out.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
            let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(max(samples.count, 1)))
            self.lock.withLock {
                self.buffer.append(contentsOf: samples)
                self._level = min(1, rms * 4)
            }
        }
        engine.prepare()
        try engine.start()
    }

    /// Stops capture and returns the recorded 16 kHz mono samples.
    public func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return lock.withLock { _level = 0; return buffer }
    }

    /// Reads any audio file and converts it to 16 kHz mono Float32.
    public static func load(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        guard let src = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let converter = AVAudioConverter(from: file.processingFormat, to: target) else { return [] }
        try file.read(into: src)
        let cap = AVAudioFrameCount(Double(src.frameLength) * 16_000 / file.processingFormat.sampleRate) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: cap) else { return [] }
        var fed = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return src
        }
        if let err { throw err }
        return Array(UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
    }
}
