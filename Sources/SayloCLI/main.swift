import Foundation
import SayloCore

// Saylo developer CLI: proves the record → transcribe → clean pipeline.
// Usage: saylo-cli [--model path/to/whistle.cact] [--file clip.wav] [--lang en]

var args = CommandLine.arguments.dropFirst()
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), args.index(after: i) < args.endIndex else { return nil }
    return args[args.index(after: i)]
}

let modelPath = option("--model") ?? "vendor/whistle.cact"
let language = option("--lang")
let keywords = ["Saylo"]
let post = TextPostProcessor(replacements: ["salo": "Saylo"])

func report(_ pcm: [Float], engine: WhistleEngine, gated: Bool = false) async throws {
    let t0 = Date()
    let t = try await engine.transcribe(pcm, language: language, keywords: keywords)
    let totalMs = Date().timeIntervalSince(t0) * 1000
    let secs = Double(pcm.count) / 16_000
    let text = post.process(t.text)
    if gated {
        print("(silence — below the speech threshold, model not run)")
        return
    }
    print(text.isEmpty ? "(silence)" : "“\(text)”")
    print(String(format: "  [%@ · audio %.1fs · ttft %.0f ms · total %.0f ms]",
                 t.language.isEmpty ? "-" : t.language, secs, t.ttftMs, totalMs))
}

do {
    let engine = try WhistleEngine(modelURL: URL(fileURLWithPath: modelPath))
    if let file = option("--file") {
        try await report(try AudioRecorder.load(url: URL(fileURLWithPath: file)), engine: engine)
    } else {
        let recorder = AudioRecorder()
        print("Saylo ▸ press Enter to start, Enter to stop (Ctrl-C quits)")
        while readLine() != nil {
            try recorder.start()
            print("● recording… press Enter to stop")
            _ = readLine()
            let pcm = recorder.stop()
            try await report(pcm, engine: engine, gated: pcm.isEmpty)
            print("\nPress Enter to dictate again")
        }
    }
} catch {
    FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
    exit(1)
}
