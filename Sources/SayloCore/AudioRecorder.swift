@preconcurrency import AVFoundation
import Foundation
import Accelerate

/// Captures the default microphone and converts it to 16 kHz mono Float32 for Whistle.
public final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var buffer: [Float] = []
    private var _level: Float = 0
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                       channels: 1, interleaved: false)!
    private var hpState: [Float] = [0, 0]

    public init() {}

    /// Current RMS level (0...1), for UI meters.
    public var level: Float { lock.withLock { _level } }

    private func highPass80Hz(_ samples: inout [Float]) {
        let fc: Float = 80.0 / 16000.0
        let rc: Float = 1.0 / (2.0 * .pi * fc)
        let alpha: Float = rc / (rc + 1.0 / 16000.0)
        var yPrev = hpState[0]
        var xPrev = hpState[1]
        for i in 0..<samples.count {
            let x = samples[i]
            let y = alpha * (yPrev + x - xPrev)
            samples[i] = y
            yPrev = y
            xPrev = x
        }
        hpState[0] = yPrev
        hpState[1] = xPrev
    }

    private func normalizeToMinus20dBFS(_ samples: inout [Float]) {
        var rms: Float = 0
        vDSP_measqv(samples, 1, &rms, vDSP_Length(samples.count))
        rms = sqrt(rms)
        guard rms > 0 else { return }
        let targetRMS: Float = pow(10.0, -20.0 / 20.0)
        let gain = targetRMS / rms
        var clampedGain = min(gain, 10.0)
        vDSP_vsmul(samples, 1, &clampedGain, &samples, 1, vDSP_Length(samples.count))
    }

    public func start() throws {
        lock.withLock { buffer.removeAll(keepingCapacity: true); hpState = [0, 0] }
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
            var samples = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
            self.highPass80Hz(&samples)
            self.normalizeToMinus20dBFS(&samples)
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
