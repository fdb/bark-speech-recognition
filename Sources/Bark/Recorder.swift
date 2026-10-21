import AVFoundation
import Foundation

/// Captures the default input device and converts it on the fly to 16 kHz mono Float32,
/// the format the model expects.
final class Recorder {
    static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    /// Called on the audio thread with the RMS level of each buffer (0…1).
    var onLevel: (Float) -> Void = { _ in }

    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private var samples: [Float] = []

    func start() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
            let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat)
        else { throw RecorderError.noInput }

        lock.withLock { samples.removeAll(keepingCapacity: true) }
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.append(buffer, converter: converter)
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    /// Stops capture and returns everything recorded since `start()`.
    func stop() -> [Float] {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        return lock.withLock { samples }
    }

    private func append(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let ratio = Self.targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        // `.noDataNow` keeps the converter's resampler state between buffers, so chunk edges stay clean.
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let data = out.floatChannelData?[0], out.frameLength > 0 else { return }
        let chunk = UnsafeBufferPointer(start: data, count: Int(out.frameLength))
        var sum: Float = 0
        for value in chunk { sum += value * value }
        onLevel((sum / Float(chunk.count)).squareRoot())
        lock.withLock { samples.append(contentsOf: chunk) }
    }
}

enum RecorderError: LocalizedError {
    case noInput
    var errorDescription: String? { "No microphone input is available." }
}
