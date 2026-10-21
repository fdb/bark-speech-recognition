import SwiftUI

struct BarkApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: menuIcon)
        }

        Window("Set Up Bark", id: "setup") {
            SetupView(state: state)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(state.setupComplete ? .suppressed : .presented)
    }

    private var menuIcon: String {
        switch state.activity {
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .idle: return state.isReady ? "waveform" : "exclamationmark.triangle"
        }
    }
}

private struct MenuContent: View {
    let state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusText)
        if !state.lastTranscript.isEmpty {
            Button("Copy Last: “\(preview(state.lastTranscript))”") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.lastTranscript, forType: .string)
            }
        }
        Divider()
        Button("Setup…") {
            openWindow(id: "setup")
            NSApp.activate()
        }
        Toggle("Open at Login", isOn: Binding(get: { state.openAtLogin }, set: { state.openAtLogin = $0 }))
        Divider()
        Button("Quit Bark") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusText: String {
        if state.microphone != .authorized { return "Microphone access needed" }
        if !state.hotkeyActive { return "Accessibility access needed" }
        switch state.model {
        case .missing: return "Speech model not downloaded"
        case .downloading: return "Downloading speech model…"
        case .preparing: return "Preparing speech model…"
        case .failed: return "Speech model failed to load"
        case .ready: return "Ready: hold right ⌥ to dictate"
        }
    }

    private func preview(_ text: String) -> String {
        text.count > 40 ? String(text.prefix(40)) + "…" : text
    }
}
