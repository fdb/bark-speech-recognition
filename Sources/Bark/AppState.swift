import AVFoundation
import AppKit
import ApplicationServices
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppState {
    enum ModelPhase: Equatable {
        case missing
        case downloading
        case preparing
        case ready
        case failed(String)
    }

    enum Activity: Equatable {
        case idle
        case recording
        case transcribing
    }

    var microphone: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    var accessibility = AXIsProcessTrusted()
    var hotkeyActive = false
    var needsInputMonitoring = false

    var model: ModelPhase = ModelStore.isDownloaded ? .preparing : .missing
    var downloadedBytes: Int64 = 0

    var activity: Activity = .idle
    var level: Float = 0
    var lastTranscript = ""
    var lastError: String?

    var setupComplete: Bool {
        didSet { UserDefaults.standard.set(setupComplete, forKey: "setupComplete") }
    }

    var openAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            guard openAtLogin != oldValue else { return }
            do {
                if openAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = error.localizedDescription
            }
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    var isReady: Bool {
        microphone == .authorized && hotkeyActive && model == .ready
    }

    private let recorder = Recorder()
    private let hotkey = Hotkey()
    private let hud = HUD()
    private var transcriber: Transcriber?
    private var recordingStart = Date()
    private var cancelled = false
    private var pollTimer: Timer?
    /// The app that received the last paste, while nothing was typed or clicked since.
    /// The next transcript into that app continues the same text and needs a separating space.
    private var continuationTarget: pid_t?

    init() {
        setupComplete = UserDefaults.standard.bool(forKey: "setupComplete")

        recorder.onLevel = { [weak self] rms in
            DispatchQueue.main.async { self?.level = rms }
        }
        hotkey.onPress = { [weak self] in MainActor.assumeIsolated { self?.beginRecording() } }
        hotkey.onRelease = { [weak self] in MainActor.assumeIsolated { self?.endRecording() } }
        hotkey.onChord = { [weak self] in MainActor.assumeIsolated { self?.cancelRecording() } }
        hotkey.onInput = { [weak self] in MainActor.assumeIsolated { self?.continuationTarget = nil } }

        // Permission changes happen in System Settings, so poll for them.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
        refreshPermissions()
        if model == .preparing { Task { await loadModel() } }
    }

    // MARK: Permissions

    func refreshPermissions() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibility = AXIsProcessTrusted()
        if accessibility, !hotkeyActive {
            hotkeyActive = hotkey.start()
            // Accessibility normally covers a listen-only tap; if it does not, Input Monitoring is the fallback.
            needsInputMonitoring = !hotkeyActive
        }
    }

    func requestMicrophone() {
        if microphone == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { self.refreshPermissions() }
            }
        } else {
            openSettings("Privacy_Microphone")
        }
    }

    func requestAccessibility() {
        // Adds Bark to the Accessibility list (switched off) so the user only has to flip the switch.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings("Privacy_Accessibility")
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openSettings("Privacy_ListenEvent")
    }

    private func openSettings(_ anchor: String) {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
    }

    // MARK: Model

    func downloadModel() {
        guard model == .missing || isFailed else { return }
        model = .downloading
        Task {
            do {
                try await ModelStore.download { bytes in
                    DispatchQueue.main.async { self.downloadedBytes = bytes }
                }
                await loadModel()
            } catch {
                model = .failed(error.localizedDescription)
            }
        }
    }

    private var isFailed: Bool {
        if case .failed = model { return true }
        return false
    }

    private func loadModel() async {
        model = .preparing
        do {
            transcriber = try await Transcriber.load()
            model = .ready
        } catch {
            model = .failed(error.localizedDescription)
        }
    }

    // MARK: Dictation

    private func beginRecording() {
        guard activity == .idle else { return }
        guard microphone == .authorized, model == .ready else {
            hud.flash(model == .ready ? "Microphone access is off" : "Speech model is not ready yet")
            return
        }
        do {
            try recorder.start()
        } catch {
            hud.flash(error.localizedDescription)
            return
        }
        cancelled = false
        recordingStart = Date()
        activity = .recording
        hud.show(self)
    }

    private func cancelRecording() {
        guard activity == .recording else { return }
        cancelled = true
        _ = recorder.stop()
        activity = .idle
        level = 0
        hud.hide()
    }

    private func endRecording() {
        guard activity == .recording, !cancelled else { return }
        let samples = recorder.stop()
        level = 0
        // A short tap of right Option is not dictation.
        guard Date().timeIntervalSince(recordingStart) > 0.3, let transcriber else {
            activity = .idle
            hud.hide()
            return
        }
        activity = .transcribing
        Task {
            defer {
                activity = .idle
                hud.hide()
            }
            do {
                let text = try await transcriber.transcribe(samples)
                guard !text.isEmpty else { return }
                lastTranscript = text
                let target = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let continues = target != nil && target == continuationTarget
                Inserter.paste(continues ? " " + text : text)
                continuationTarget = target
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
