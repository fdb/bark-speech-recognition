import Foundation

// `Bark --transcribe file.wav` runs headless: downloads the model if needed, prints the text and timing.
// Used to check the speech pipeline without the menu bar UI.
let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--transcribe"), index + 1 < arguments.count {
    let url = URL(fileURLWithPath: arguments[index + 1])
    let done = DispatchSemaphore(value: 0)
    Task {
        do {
            if !ModelStore.isDownloaded {
                FileHandle.standardError.write("Downloading model to \(ModelStore.directory.path)\n".data(using: .utf8)!)
                try await ModelStore.download { _ in }
            }
            var start = Date()
            let transcriber = try await Transcriber.load()
            FileHandle.standardError.write(String(format: "load: %.2fs\n", Date().timeIntervalSince(start)).data(using: .utf8)!)
            start = Date()
            let text = try await transcriber.transcribe(file: url)
            FileHandle.standardError.write(String(format: "transcribe: %.3fs\n", Date().timeIntervalSince(start)).data(using: .utf8)!)
            print(text)
        } catch {
            FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
        done.signal()
    }
    done.wait()
    exit(0)
}

BarkApp.main()
