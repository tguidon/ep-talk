import SwiftUI

struct RecordShortcutView: View {
    var finish: (Shortcut?) -> Void
    @State private var monitor: Any?
    @State private var feedback = "Press your shortcut, then release its keys."
    @State private var heldModifiers: [UInt16] = []
    @State private var pressedModifiers: [UInt16] = []
    @State private var pendingShortcut: Shortcut?
    @State private var sawRegularKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Press the shortcut")
                .font(.system(size: 24, weight: .semibold))
            Text(feedback)
                .foregroundStyle(ConsolePalette.secondary)
            HStack {
                Spacer()
                Button("Cancel") { finish(nil) }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 365)
        .foregroundStyle(ConsolePalette.text)
        .background(ConsolePalette.chassis)
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
                if event.type == .flagsChanged {
                    recordModifier(event)
                } else if !event.isARepeat {
                    recordKey(event)
                }
                return nil
            }
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }

    private func recordModifier(_ event: NSEvent) {
        guard let flag = Shortcut.flag(for: event.keyCode) else { return }
        if let index = heldModifiers.firstIndex(of: event.keyCode) {
            heldModifiers.remove(at: index)
            guard heldModifiers.isEmpty else { return }
            if let shortcut = pendingShortcut ?? (sawRegularKey ? nil : Shortcut(modifierCodes: pressedModifiers)) {
                finish(shortcut)
            }
            pressedModifiers = []
            sawRegularKey = false
        } else if CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).contains(flag) {
            heldModifiers.append(event.keyCode)
            // Keep exactly the modifiers that were held together.
            if heldModifiers.count >= pressedModifiers.count { pressedModifiers = heldModifiers }
        }
    }

    private func recordKey(_ event: NSEvent) {
        if event.keyCode == 53 { finish(nil); return }
        sawRegularKey = true
        pendingShortcut = nil
        guard let shortcut = Shortcut(event: event, modifierCodes: heldModifiers) else {
            feedback = "Try again with a modifier key."
            return
        }
        if shortcut.flags.contains(.maskCommand) && [UInt16(12), 13, 48, 49].contains(event.keyCode) {
            feedback = "Choose a shortcut that macOS doesn’t reserve."
            return
        }
        if heldModifiers.isEmpty {
            finish(shortcut)
        } else {
            pendingShortcut = shortcut
            feedback = "Release the keys to save."
        }
    }
}
