/// Splits long 16 kHz audio into ≤30 s chunks, cutting at the quietest 80 ms
/// window between 25 s and 30 s so words are not sliced in half.
public enum AudioChunker {
    public static func chunk(_ pcm: [Float], sampleRate: Int = 16_000,
                             maxSeconds: Double = 30, searchSeconds: Double = 5) -> [[Float]] {
        guard sampleRate > 0, maxSeconds > 0 else { return [pcm] }

        let maxLen = max(1, Int(maxSeconds * Double(sampleRate)))
        guard pcm.count > maxLen else { return [pcm] }

        let window = max(1, sampleRate * 80 / 1000)
        // The search window must stay inside the chunk and strictly ahead of
        // `start`; otherwise `bestCut` can land before `start`, `start` moves
        // backwards, and the loop never terminates.
        let searchLen = min(max(0, Int(searchSeconds * Double(sampleRate))), maxLen - 1)

        var chunks: [[Float]] = []
        var start = 0
        while pcm.count - start > maxLen {
            let lo = start + maxLen - searchLen
            var bestCut = start + maxLen
            var bestEnergy = Float.greatestFiniteMagnitude
            var w = lo
            while w + window <= start + maxLen {
                var e: Float = 0
                for i in w..<(w + window) { e += pcm[i] * pcm[i] }
                if e < bestEnergy { bestEnergy = e; bestCut = w + window / 2 }
                w += window
            }
            // Defensive: a cut at or before `start` would stall the loop.
            if bestCut <= start { bestCut = start + maxLen }
            chunks.append(Array(pcm[start..<bestCut]))
            start = bestCut
        }
        chunks.append(Array(pcm[start...]))
        return chunks
    }
}
