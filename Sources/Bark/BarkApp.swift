import SwiftUI

struct BarkApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            if state.activity == .idle, state.isReady, let dog = Self.menuBarDog {
                Image(nsImage: dog)
            } else {
                Image(systemName: menuIcon)
            }
        }

        Window("Set Up Bark", id: "setup") {
            SetupView(state: state)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(state.setupComplete ? .suppressed : .presented)
    }

    /// The dog from artwork/bark-menubar.svg, as a template image so macOS tints it for the menu bar.
    private static let menuBarDog: NSImage? = {
        guard let image = NSImage(named: "MenuBarIcon") else { return nil }
        image.isTemplate = true
        return image
    }()

    private var menuIcon: String {
        switch state.activity {
        case .recording: return "mic.fill"
        case .transcribing: return "ellipsis.circle"
        case .idle:
            if state.isReady { return "waveform" }
            if state.model == .downloading || state.model == .preparing { return "hourglass" }
            return "exclamationmark.triangle"
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
        case .preparing: return "Preparing speech model (first launch takes about 1.5 min)…"
        case .failed: return "Speech model failed to load"
        case .ready: return "Ready: hold right ⌥ to dictate"
        }
    }

    private func preview(_ text: String) -> String {
        text.count > 40 ? String(text.prefix(40)) + "…" : text
    }
}
