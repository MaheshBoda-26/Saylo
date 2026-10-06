import Foundation
import Accelerate

/// Energy-based speech/silence detection over 16 kHz mono PCM.
///
/// Speech models hallucinate short stock phrases ("Thank you.", "Bye.") when fed
/// non-speech audio, so silence has to be rejected before transcription rather
/// than cleaned up afterwards.
public enum SpeechActivity {
    /// Loudest window RMS accepted as speech, about -42 dBFS. Room tone measures
    /// roughly -50 dBFS and quiet speech at desk distance -30 dBFS, so both sides
    /// keep margin.
    public static let speechThreshold: Float = 0.008

    /// Largest RMS found across any `windowSeconds` slice of `pcm`.
    ///
    /// Whole-clip RMS is unusable as a speech measure: a brief utterance in a long
    /// silence-heavy clip averages down below any threshold that would also admit
    /// background noise. The loudest window tracks speech level directly.
    public static func peakWindowRMS(_ pcm: [Float], sampleRate: Int = 16_000,
                                     windowSeconds: Double = 0.1) -> Float {
        guard !pcm.isEmpty else { return 0 }
        let window = max(1, Int(windowSeconds * Double(sampleRate)))
        if pcm.count <= window { return rms(pcm) }

        var peak: Float = 0
        var start = 0
        while start < pcm.count {
            let end = min(start + window, pcm.count)
            peak = max(peak, rms(pcm[start..<end]))
            start += window
        }
        return peak
    }

    /// True when `pcm` contains a window loud enough to be speech.
    public static func containsSpeech(_ pcm: [Float], threshold: Float = speechThreshold,
                                      sampleRate: Int = 16_000) -> Bool {
        peakWindowRMS(pcm, sampleRate: sampleRate) >= threshold
    }

    /// Root-mean-square amplitude of a slice, 0 for an empty slice.
    public static func rms<C: Collection>(_ samples: C) -> Float where C.Element == Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Scales `samples` so the loudest window sits at `target`, never by more than
    /// `maxGain`. Normalizing once over the whole clip keeps silence quiet relative
    /// to speech; normalizing each capture buffer separately would lift silence to
    /// the same level as speech and defeat the silence check.
    ///
    /// A clip quieter than `speechThreshold` is left untouched, so this is safe to
    /// call without normalizing first: gain can never lift noise into speech range.
    public static func normalize(_ samples: inout [Float], reference: Float,
                                 target: Float = targetRMS, maxGain: Float = 10) {
        guard reference >= speechThreshold else { return }
        let gain = min(target / reference, maxGain)
        var g = gain
        vDSP_vsmul(samples, 1, &g, &samples, 1, vDSP_Length(samples.count))
    }

    /// Nominal clip level: -20 dBFS, matching the engine's preferred input range.
    public static let targetRMS: Float = 0.1

    /// Maps an RMS amplitude onto 0...1 for a level meter using a -60 dBFS floor,
    /// so room tone reads as silence instead of a live waveform.
    public static func meterLevel(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return max(0, min(1, (db + 60) / 60))
    }
}