import AppKit
import ApplicationServices

struct Shortcut: Codable, Equatable {
    private struct Modifier {
        let left: UInt16
        let right: UInt16
        let flag: CGEventFlags
        let leftMask: UInt64
        let rightMask: UInt64
        let symbol: String
        let name: String
    }

    // Device-dependent modifier bits from IOKit/hidsystem/IOLLEvent.h.
    private static let modifierKeys: [Modifier] = [
        .init(left: 59, right: 62, flag: .maskControl, leftMask: 0x0001, rightMask: 0x2000, symbol: "⌃", name: "Control"),
        .init(left: 58, right: 61, flag: .maskAlternate, leftMask: 0x0020, rightMask: 0x0040, symbol: "⌥", name: "Option"),
        .init(left: 56, right: 60, flag: .maskShift, leftMask: 0x0002, rightMask: 0x0004, symbol: "⇧", name: "Shift"),
        .init(left: 55, right: 54, flag: .maskCommand, leftMask: 0x0008, rightMask: 0x0010, symbol: "⌘", name: "Command")
    ]

    var keyCode: UInt16?
    var modifiers = CGEventFlags.maskAlternate.union(.maskCommand).rawValue
    var modifierKeyCodes: [UInt16]? = [58, 55]
    var name = ""

    var flags: CGEventFlags { CGEventFlags(rawValue: modifiers) }

    var modifierEvents: [(code: CGKeyCode, flag: CGEventFlags)] {
        Self.modifierKeys.compactMap { key in
            guard flags.contains(key.flag) else { return nil }
            let side = modifierKeyCodes?.first { $0 == key.left || $0 == key.right } ?? key.left
            let mask = side == key.right ? key.rightMask : key.leftMask
            return (side, CGEventFlags(rawValue: key.flag.rawValue | mask))
        }
    }

    var label: String {
        let symbols = Self.modifierKeys.filter { flags.contains($0.flag) }.map(\.symbol)
        return (symbols + (name.isEmpty ? [] : [name])).joined(separator: " ")
    }

    var spokenLabel: String {
        let names = Self.modifierKeys.filter { flags.contains($0.flag) }.map { key in
            let right = modifierKeyCodes?.contains(key.right) == true
            return "\(right ? "Right" : "Left") \(key.name)"
        }
        return (names + (name.isEmpty ? [] : [name])).joined(separator: " plus ")
    }

    init() {}

    init?(modifierCodes: [UInt16]) {
        let flags = modifierCodes.compactMap(Self.flag(for:))
        guard !flags.isEmpty, Set(flags.map(\.rawValue)).count == flags.count else { return nil }
        keyCode = nil
        modifiers = flags.reduce(into: CGEventFlags()) { $0.insert($1) }.rawValue
        modifierKeyCodes = modifierCodes
        name = ""
    }

    @MainActor init?(event: NSEvent, modifierCodes: [UInt16]) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !flags.isEmpty else { return nil }
        let special: [UInt16: String] = [
            49: "Space", 36: "Return", 48: "Tab", 51: "Delete",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "Left", 124: "Right", 125: "Down", 126: "Up"
        ]
        keyCode = event.keyCode
        modifiers = UInt64(flags.rawValue)
        modifierKeyCodes = modifierCodes
        name = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
    }

    static func flag(for code: UInt16) -> CGEventFlags? {
        modifierKeys.first { $0.left == code || $0.right == code }?.flag
    }
}

@MainActor
final class ShortcutOutput {
    private var releaseEvents: [CGEvent] = []
    private let source = CGEventSource(stateID: .privateState)

    var hasAccess: Bool { AXIsProcessTrusted() }

    func requestAccess() {
        _ = CGRequestPostEventAccess()
    }

    func press(_ shortcut: Shortcut) -> Bool {
        guard hasAccess, let source, !shortcut.modifierEvents.isEmpty else { return false }
        release()
        let modifiers = shortcut.modifierEvents
        var current: CGEventFlags = []
        var downEvents: [CGEvent] = []
        var upEvents: [CGEvent] = []

        for (code, flag) in modifiers {
            current.insert(flag)
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) else {
                return false
            }
            event.type = .flagsChanged
            event.flags = current
            downEvents.append(event)
        }
        if let keyCode = shortcut.keyCode {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
                return false
            }
            down.flags = current
            up.flags = current
            downEvents.append(down)
            upEvents.append(up)
        }
        for (code, flag) in modifiers.reversed() {
            current.remove(flag)
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
                return false
            }
            event.type = .flagsChanged
            event.flags = current
            upEvents.append(event)
        }
        releaseEvents = upEvents
        for event in downEvents { event.post(tap: .cghidEventTap) }
        return true
    }

    func release() {
        for event in releaseEvents { event.post(tap: .cghidEventTap) }
        releaseEvents.removeAll(keepingCapacity: true)
    }
}
