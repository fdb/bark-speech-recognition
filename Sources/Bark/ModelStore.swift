import CoreML
import FluidAudio
import Foundation

/// Downloads the Bark 3.0 Clean Core ML pipeline (FluidInference/bark-3.0-coreml, pinned commit)
/// and loads it into a FluidAudio `AsrManager`.
enum ModelStore {
    static let repo = "FluidInference/bark-3.0-coreml"
    static let revision = "ca21bed2ccd9c3fbcd104a6014b9a5638a764bc8"
    static let folder = "bark-3.0-clean"

    /// Files and their exact sizes at `revision`. The GPU encoder (`Encoder_lut3`) is left out:
    /// the app runs the encoder on the Neural Engine.
    static let files: [(path: String, size: Int64)] = [
        ("Preprocessor.mlmodelc/analytics/coremldata.bin", 243),
        ("Preprocessor.mlmodelc/coremldata.bin", 486),
        ("Preprocessor.mlmodelc/metadata.json", 2841),
        ("Preprocessor.mlmodelc/model.mil", 28181),
        ("Preprocessor.mlmodelc/weights/weight.bin", 491_072),
        ("Encoder.mlmodelc/analytics/coremldata.bin", 243),
        ("Encoder.mlmodelc/coremldata.bin", 557),
        ("Encoder.mlmodelc/model.mil", 1_012_893),
        ("Encoder.mlmodelc/weights/weight.bin", 409_451_136),
        ("Decoder.mlmodelc/analytics/coremldata.bin", 243),
        ("Decoder.mlmodelc/coremldata.bin", 569),
        ("Decoder.mlmodelc/metadata.json", 3433),
        ("Decoder.mlmodelc/model.mil", 13110),
        ("Decoder.mlmodelc/weights/weight.bin", 23_604_992),
        ("JointDecisionv3.mlmodelc/analytics/coremldata.bin", 243),
        ("JointDecisionv3.mlmodelc/coremldata.bin", 601),
        ("JointDecisionv3.mlmodelc/metadata.json", 3577),
        ("JointDecisionv3.mlmodelc/model.mil", 11777),
        ("JointDecisionv3.mlmodelc/weights/weight.bin", 12_642_764),
        ("parakeet_vocab.json", 151_122),
        ("NOTICE", 615),
    ]

    static var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bark", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
    }

    static var isDownloaded: Bool {
        files.allSatisfy { size(of: directory.appendingPathComponent($0.path)) == $0.size }
    }

    private static func size(of url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }

    /// Downloads every missing file. `progress` receives bytes done so far (main thread not guaranteed).
    static func download(progress: @escaping @Sendable (Int64) -> Void) async throws {
        let fm = FileManager.default
        var done: Int64 = 0
        for file in files {
            let dest = directory.appendingPathComponent(file.path)
            if size(of: dest) == file.size {
                done += file.size
                progress(done)
                continue
            }
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            let url = URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(folder)/\(file.path)")!
            let base = done
            let delegate = ProgressDelegate { progress(base + $0) }
            let (tmp, response) = try await URLSession.shared.download(from: url, delegate: delegate)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw BarkError.download("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) for \(file.path)")
            }
            guard size(of: tmp) == file.size else {
                throw BarkError.download("Unexpected size for \(file.path)")
            }
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: tmp, to: dest)
            done += file.size
            progress(done)
        }
    }

    /// Loads the models. The first load compiles the encoder for the Neural Engine, which can take a minute;
    /// Core ML caches the result for later launches.
    static func load() async throws -> AsrManager {
        let models = try AsrModels.loadLocal(from: directory, version: .ultra)
        let asr = AsrManager(config: .default)
        try await asr.loadModels(models)
        return asr
    }
}

enum BarkError: LocalizedError {
    case download(String)
    var errorDescription: String? {
        switch self {
        case .download(let message): return "Download failed: \(message)"
        }
    }
}

private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onBytes: (Int64) -> Void
    init(onBytes: @escaping (Int64) -> Void) { self.onBytes = onBytes }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        onBytes(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
