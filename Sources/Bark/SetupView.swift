import AVFoundation
import SwiftUI

struct SetupView: View {
    @Bindable var state: AppState
    @State private var step: Step = .welcome
    @Environment(\.dismissWindow) private var dismissWindow

    enum Step: Int, CaseIterable, Identifiable {
        case welcome, microphone, accessibility, model, tryIt
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .microphone: return "Microphone"
            case .accessibility: return "Accessibility"
            case .model: return "Speech Model"
            case .tryIt: return "Try It"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                footer
            }
            .padding(32)
        }
        .frame(width: 720, height: 460)
        .onAppear {
            NSApp.activate()
            step = firstIncompleteStep
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "waveform").font(.title2).foregroundStyle(.tint)
                Text("Bark").font(.title2.weight(.semibold))
            }
            .padding(.bottom, 20)
            ForEach(Step.allCases) { item in
                Button { step = item } label: { stepRow(item) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Step \(item.rawValue + 1): \(item.title)")
            }
            Spacer()
            Text("Runs entirely on this Mac.\nNo audio leaves it.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 200, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(.background.secondary)
    }

    private func stepRow(_ item: Step) -> some View {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(isDone(item) ? Color.green : (item == step ? Color.accentColor : Color.secondary.opacity(0.2)))
                            .frame(width: 22, height: 22)
                        if isDone(item) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        } else {
                            Text("\(item.rawValue + 1)").font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(item == step ? .white : .secondary)
                        }
                    }
                    Text(item.title).fontWeight(item == step ? .semibold : .regular)
                        .foregroundStyle(item == step ? .primary : .secondary)
                }
                .padding(.vertical, 5)
                .contentShape(Rectangle())
    }

    private func isDone(_ item: Step) -> Bool {
        switch item {
        case .welcome: return step.rawValue > 0
        case .microphone: return state.microphone == .authorized
        case .accessibility: return state.hotkeyActive
        case .model: return state.model == .ready
        case .tryIt: return state.setupComplete
        }
    }

    private var firstIncompleteStep: Step {
        if !state.setupComplete, state.microphone == .notDetermined { return .welcome }
        return [.microphone, .accessibility, .model].first { !isDone($0) } ?? .tryIt
    }

    // MARK: Pages

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            Page(
                icon: "waveform", title: "Dictate anywhere",
                text: """
                    Hold the right Option key (⌥) and talk. When you let go, Bark writes what you said \
                    into whatever text field you are in, in any app.

                    Bark uses Underdog Bark 3.0 Clean, a speech model that leaves out “um”, “uh”, \
                    false starts and repeated words. It runs on your Mac's Neural Engine.

                    Setup takes three steps: two permissions and a one-time model download.
                    """)

        case .microphone:
            Page(
                icon: "mic.fill", title: "Allow the microphone",
                text: """
                    Bark listens only while you hold right ⌥. The microphone indicator in the menu bar \
                    shows when it is on.
                    """
            ) {
                StatusRow(done: state.microphone == .authorized, doneText: "Microphone access is on") {
                    Button(state.microphone == .notDetermined ? "Allow Microphone" : "Open Microphone Settings") {
                        state.requestMicrophone()
                    }
                    .controlSize(.large)
                    if state.microphone == .denied {
                        Text("Access was turned off earlier. Turn on Bark in System Settings.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

        case .accessibility:
            Page(
                icon: "keyboard", title: "Allow Accessibility",
                text: """
                    macOS asks for this so Bark can notice the right ⌥ key while you work in other apps, \
                    and paste the text into them.

                    Click the button, then turn on Bark in the list. This page updates by itself.
                    """
            ) {
                StatusRow(done: state.hotkeyActive, doneText: "Accessibility access is on") {
                    Button("Open Accessibility Settings") { state.requestAccessibility() }
                        .controlSize(.large)
                    if state.needsInputMonitoring {
                        Text("macOS also wants Input Monitoring for the key. Turn on Bark there too.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Open Input Monitoring Settings") { state.requestInputMonitoring() }
                    }
                }
            }

        case .model:
            Page(
                icon: "cpu", title: "Download the speech model",
                text: """
                    Bark 3.0 Clean in Core ML format, \(ByteCountFormatter.string(fromByteCount: ModelStore.totalBytes, countStyle: .file)) \
                    from Hugging Face. After the download, macOS prepares the model for the Neural Engine. \
                    That takes about a minute, only the first time.
                    """
            ) {
                modelStatus
            }

        case .tryIt:
            Page(
                icon: "text.cursor", title: "Try it",
                text: "Click in the box, hold right ⌥, say a sentence, and let go."
            ) {
                TryItField()
                if !state.isReady {
                    Label("Finish the earlier steps first.", systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }
                Toggle("Open Bark at login", isOn: Binding(get: { state.openAtLogin }, set: { state.openAtLogin = $0 }))
            }
        }
    }

    @ViewBuilder
    private var modelStatus: some View {
        switch state.model {
        case .missing:
            Button("Download") { state.downloadModel() }.controlSize(.large)
        case .downloading:
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(state.downloadedBytes), total: Double(ModelStore.totalBytes))
                Text(
                    "\(ByteCountFormatter.string(fromByteCount: state.downloadedBytes, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: ModelStore.totalBytes, countStyle: .file))"
                )
                .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(maxWidth: 360)
        case .preparing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Preparing for the Neural Engine…").foregroundStyle(.secondary)
            }
        case .ready:
            Label("Model ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                Button("Try Again") { state.downloadModel() }
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step != .welcome {
                Button("Back") { step = Step(rawValue: step.rawValue - 1)! }
            }
            Spacer()
            if step == .tryIt {
                Button("Done") {
                    state.setupComplete = true
                    dismissWindow(id: "setup")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!state.isReady)
            } else {
                Button(step == .welcome ? "Get Started" : "Continue") {
                    step = Step(rawValue: step.rawValue + 1)!
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
            }
        }
        .controlSize(.large)
    }

    private var canContinue: Bool {
        switch step {
        case .welcome: return true
        case .microphone, .accessibility, .model: return isDone(step)
        case .tryIt: return false
        }
    }
}

private struct Page<Extra: View>: View {
    let icon: String
    let title: String
    let text: String
    @ViewBuilder var extra: () -> Extra

    init(icon: String, title: String, text: String, @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.text = text
        self.extra = extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.tint)
                .frame(height: 40)
            Text(title).font(.title.weight(.semibold))
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12, content: extra).padding(.top, 8)
        }
    }
}

private struct StatusRow<Action: View>: View {
    let done: Bool
    let doneText: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        if done {
            Label(doneText, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 10, content: action)
        }
    }
}

private struct TryItField: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(height: 110)
            .background(RoundedRectangle(cornerRadius: 8).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? Color.accentColor : .secondary.opacity(0.3)))
            .focused($focused)
            .onAppear { focused = true }
    }
}
