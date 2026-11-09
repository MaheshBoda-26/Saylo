import AVFoundation
import Foundation

/// Small read-only facts the UI displays instead of hardcoded strings.
enum AppInfo {
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, !build.isEmpty { return "\(short) (\(build))" }
        return short
    }

    /// On-disk size of the bundled speech model, or `nil` when it is missing.
    static var modelSize: String? {
        guard let url = Bundle.main.url(forResource: "whistle", withExtension: "cact"),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = (attributes[.size] as? NSNumber)?.int64Value,
              bytes > 0 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static var defaultInputName: String {
        AVCaptureDevice.default(for: .audio)?.localizedName ?? "System Default"
    }
}
