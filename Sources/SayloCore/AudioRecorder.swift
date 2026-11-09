@preconcurrency import AVFoundation
import Foundation

/// Captures the default microphone and converts it to 16 kHz mono Float32 for Whistle.
public final class AudioRecorder: @unchecked Sendable {
    public enum RecorderError: Error, LocalizedError {
        case noInputDevice
        case converterUnavailable
        case bufferAllocationFailed
        case unreadableFile(String)

        public var errorDescription: String? {
            switch self {
            case .noInputDevice: return "No microphone input is available."
            case .converterUnavailable: return "The audio converter could not be created."
            case .bufferAllocationFailed: return "The audio buffer could not be allocated."
            case .unreadableFile(let reason): return "The audio file could not be read: \(reason)"
            }
        }
    }

    /// Upper bound on a single capture. Long dictations are chunked by the
    /// engine, but the buffer still has to be finite: a forgotten hands-free
    /// session would otherwise grow by ~230 MB per hour.
    public static let maxCaptureSeconds: Double = 300

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var buffer: [Float] = []
    private var _level: Float = 0
    private var _wasSilent = false
    private var _reachedLimit = false
    private var tapInstalled = false
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                       channels: 1, interleaved: false)!
    private var hpState: [Float] = [0, 0]

    /// True when the most recent `stop()` rejected the clip as silence.
    public var wasSilent: Bool { lock.withLock { _wasSilent } }

    /// True once the capture hit `maxCaptureSeconds` and stopped accepting audio.
    public var reachedLimit: Bool { lock.withLock { _reachedLimit } }

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

    public func start() throws {
        // A tap left behind by a failed start would make the next
        // `installTap` raise an uncatchable exception.
        teardownTap()

        lock.withLock {
            buffer.removeAll(keepingCapacity: true)
            hpState = [0, 0]
            _wasSilent = false
            _reachedLimit = false
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw RecorderError.noInputDevice
        }
        guard let converter = AVAudioConverter(from: format, to: target) else {
            throw RecorderError.converterUnavailable
        }

        let ratio = target.sampleRate / format.sampleRate
        let maxSamples = Int(Self.maxCaptureSeconds * target.sampleRate)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] pcm, _ in
            guard let self else { return }

            let capacity = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 32
            guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: capacity) else { return }

            var fed = false
            converter.convert(to: out, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return pcm
            }
            guard let channel = out.floatChannelData?[0] else { return }

            var samples = Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
            self.highPass80Hz(&samples)

            // Level is read before any gain so the meter reflects the true input.
            let rms = SpeechActivity.rms(samples)
            self.lock.withLock {
                guard !self._reachedLimit else { return }
                if self.buffer.count + samples.count > maxSamples {
                    let room = max(0, maxSamples - self.buffer.count)
                    self.buffer.append(contentsOf: samples.prefix(room))
                    self._reachedLimit = true
                    self._level = 0
                    return
                }
                self.buffer.append(contentsOf: samples)
                self._level = SpeechActivity.meterLevel(rms: rms)
            }
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            teardownTap()
            throw error
        }
    }

    /// Stops capture and returns the recorded 16 kHz mono samples, level-normalized
    /// once for the whole clip. Returns an empty array when the clip held no speech,
    /// so silence never reaches the model — speech models answer non-speech audio
    /// with invented phrases like "Thank you." or "Bye.".
    public func stop() -> [Float] {
        teardownTap()
        return lock.withLock {
            _level = 0
            guard !buffer.isEmpty else { return [] }

            let reference = SpeechActivity.peakWindowRMS(buffer)
            guard reference >= SpeechActivity.speechThreshold else {
                _wasSilent = true
                return []
            }
            _wasSilent = false
            SpeechActivity.normalize(&buffer, reference: reference)
            return buffer
        }
    }

    /// Removes the input tap if one is installed. Safe to call repeatedly.
    private func teardownTap() {
        guard tapInstalled else { return }
        tapInstalled = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Reads any audio file and converts it to 16 kHz mono Float32.
    public static func load(url: URL) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw RecorderError.unreadableFile(error.localizedDescription)
        }

        let format = file.processingFormat
        guard format.sampleRate > 0 else {
            throw RecorderError.unreadableFile("unknown sample rate")
        }
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                         channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: target) else {
            throw RecorderError.converterUnavailable
        }

        let sourceCapacity = AVAudioFrameCount(clamping: file.length)
        guard sourceCapacity > 0,
              let source = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sourceCapacity) else {
            throw RecorderError.bufferAllocationFailed
        }
        try file.read(into: source)

        let outputFrames = Double(source.frameLength) * 16_000 / format.sampleRate + 32
        let outputCapacity = AVAudioFrameCount(min(Double(UInt32.max), max(0, outputFrames)))
        guard outputCapacity > 0,
              let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outputCapacity) else {
            throw RecorderError.bufferAllocationFailed
        }

        var fed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return source
        }
        if let conversionError { throw conversionError }
        guard let channel = output.floatChannelData?[0] else {
            throw RecorderError.bufferAllocationFailed
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }
}
