import AppKit
import SwiftUI

/// A small pill near the bottom of the screen that shows Bark is listening or transcribing.
/// It never takes focus, so the paste lands in the app the user was typing in.
@MainActor
final class HUD {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(_ state: AppState) {
        present(HUDView(state: state, message: nil))
    }

    func flash(_ message: String) {
        present(HUDView(state: nil, message: message))
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        panel?.orderOut(nil)
    }

    private func present(_ view: HUDView) {
        hideWork?.cancel()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        let size = host.fittingSize
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrame(
                NSRect(x: frame.midX - size.width / 2, y: frame.minY + 72, width: size.width, height: size.height),
                display: true)
        }
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}

private struct HUDView: View {
    let state: AppState?
    let message: String?

    var body: some View {
        HStack(spacing: 10) {
            if let message {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.yellow)
                Text(message)
            } else if let state, state.activity == .transcribing {
                ProgressView().controlSize(.small)
                Text("Transcribing")
            } else if let state {
                LevelBars(level: state.level)
                Text("Listening")
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.black.opacity(0.82)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .padding(8)
        .fixedSize()
    }
}

private struct LevelBars: View {
    let level: Float
    private let weights: [Float] = [0.5, 0.8, 1.0, 0.8, 0.5]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(weights.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.red)
                    .frame(width: 3, height: height(weights[i]))
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.08), value: level)
    }

    private func height(_ weight: Float) -> CGFloat {
        // Speech RMS sits around 0.01–0.2; scale it to the bar range on a soft curve.
        let normalized = min(1, (level * 12).squareRoot())
        return CGFloat(4 + 14 * normalized * weight)
    }
}
