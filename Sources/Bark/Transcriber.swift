import FluidAudio
import Foundation

/// Wraps the loaded `AsrManager`. Each utterance gets a fresh decoder state.
actor Transcriber {
    private let asr: AsrManager

    init(asr: AsrManager) { self.asr = asr }

    static func load() async throws -> Transcriber {
        let transcriber = Transcriber(asr: try await ModelStore.load())
        // Run one second of silence so the first real utterance does not pay for warm-up.
        _ = try? await transcriber.transcribe([Float](repeating: 0, count: 16_000))
        return transcriber
    }

    /// `samples` are 16 kHz mono Float32.
    func transcribe(_ samples: [Float]) async throws -> String {
        var state = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
        let result = try await asr.transcribe(samples, decoderState: &state)
        // Bark emits <unk> where its training text had a quotation mark; FluidAudio 0.17.7 keeps it.
        return result.text
            .replacingOccurrences(of: "<unk>", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func transcribe(file url: URL) async throws -> String {
        try await transcribe(AudioConverter().resampleAudioFile(url))
    }
}
