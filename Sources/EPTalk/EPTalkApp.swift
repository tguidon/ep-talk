import AppKit
import SwiftUI

@main
@MainActor
enum EPTalkApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = ConsoleModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var armItem: NSMenuItem?
    private var readoutItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenus()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(sleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        model.start()
        observeMenu()
        let launchReason = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)
        let loginLaunch = launchReason?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch { showConsole() }
    }

    private func configureMenus() {
        let applicationMenu = NSMenu()
        let root = NSMenuItem()
        root.submenu = applicationMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(root)
        NSApp.mainMenu = mainMenu
        applicationMenu.addItem(withTitle: "About EP Talk", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Show EP Talk", action: #selector(showConsole), keyEquivalent: "0").target = self
        applicationMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit EP Talk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        let menu = NSMenu()
        item.menu = menu
        readoutItem = menu.addItem(withTitle: "Standby", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show EP Talk", action: #selector(showConsole), keyEquivalent: "").target = self
        armItem = menu.addItem(withTitle: "Arm", action: #selector(toggleArm), keyEquivalent: "")
        armItem?.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit EP Talk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func observeMenu() {
        withObservationTracking {
            armItem?.title = model.armed ? "Disarm" : "Arm"
            readoutItem?.title = model.readout.title
            let image = NSImage(systemSymbolName: model.isTransmitting ? "mic.fill" : "waveform",
                                accessibilityDescription: "EP Talk: \(model.readout.title)")
            image?.isTemplate = true
            statusItem?.button?.image = image
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeMenu() }
        }
    }

    @objc private func showConsole() {
        if window == nil {
            let host = NSHostingController(rootView: ConsoleView(model: model))
            let created = NSWindow(contentViewController: host)
            created.title = "EP Talk"
            created.titleVisibility = .hidden
            created.titlebarAppearsTransparent = true
            created.styleMask.insert(.fullSizeContentView)
            created.styleMask.remove(.resizable)
            created.isReleasedWhenClosed = false
            created.backgroundColor = NSColor(ConsolePalette.chassis)
            created.appearance = NSAppearance(named: .darkAqua)
            created.setContentSize(host.view.fittingSize)
            created.center()
            window = created
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc private func toggleArm() { model.armed.toggle() }
    @objc private func sleep() { model.sleep() }
    @objc private func wake() { model.wake() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showConsole()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        model.stop()
    }
}
