import CoreGraphics
import Foundation

/// Watches the right Option key system-wide with a listen-only event tap.
/// Needs Accessibility (or Input Monitoring) permission; `start()` returns false without it.
final class Hotkey {
    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    /// Another key was pressed while right Option was down (e.g. ⌥E for an accent): not dictation.
    var onChord: () -> Void = {}

    private static let rightOptionKeyCode: Int64 = 61
    private static let rightOptionDeviceMask: UInt64 = 0x40  // NX_DEVICERALTKEYMASK

    private var tap: CFMachPort?
    private var isDown = false

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                eventsOfInterest: CGEventMask(mask),
                callback: { _, type, event, refcon in
                    let hotkey = Unmanaged<Hotkey>.fromOpaque(refcon!).takeUnretainedValue()
                    hotkey.handle(type: type, event: event)
                    return Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .flagsChanged:
            guard event.getIntegerValueField(.keyboardEventKeycode) == Self.rightOptionKeyCode else { return }
            let down = event.flags.rawValue & Self.rightOptionDeviceMask != 0
            if down, !isDown {
                isDown = true
                onPress()
            } else if !down, isDown {
                isDown = false
                onRelease()
            }
        case .keyDown:
            if isDown { onChord() }
        default:
            break
        }
    }
}
