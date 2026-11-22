import AppKit
import AVFoundation
import EPTalkCore
import Observation
import ServiceManagement

@MainActor
@Observable
final class ConsoleModel {
    enum Readout {
        case permission, noInput, standby, searching, release, ready, transmitting, sleeping, fault, keyboard

        var title: String {
            switch self {
            case .permission: "Access needed"
            case .noInput: "No input"
            case .standby: "Standby"
            case .searching: "Acquiring link"
            case .release: "Release paddle"
            case .ready: "Ready"
            case .transmitting: "Transmitting"
            case .sleeping: "Suspended"
            case .fault: "Input offline"
            case .keyboard: "Access needed"
            }
        }
    }

    var armed: Bool {
        didSet {
            defaults.set(armed, forKey: "armed")
            guard armed != oldValue else { return }
            stopCapture()
            refresh()
        }
    }
    var inputUID: String {
        didSet {
            defaults.set(inputUID, forKey: "audioInputUID")
            guard inputUID != oldValue else { return }
            stopCapture()
            refresh()
        }
    }
    var shortcut: Shortcut {
        didSet {
            guard oldValue != shortcut else { return }
            keyboard.release()
            isTransmitting = false
            _ = session.reset()
            defaults.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
        }
    }

    private(set) var inputs: [AudioInput] = []
    private(set) var inputLevel = -60.0
    private(set) var micAllowed = false
    private(set) var keyboardAllowed = false
    private(set) var capturing = false
    private(set) var isTransmitting = false
    private(set) var loginEnabled = false
    private(set) var installing = false
    private(set) var setupMessage: String?
    var notice: String?
    var recordingShortcut = false {
        didSet {
            keyboard.release()
            isTransmitting = false
            _ = session.reset()
        }
    }

    @ObservationIgnored private var receiver: AudioCapture?
    @ObservationIgnored private var captureID: AudioDeviceID?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let keyboard = ShortcutOutput()
    @ObservationIgnored private let defaults: UserDefaults
    private var session = HoldSession()
    private var sleeping = false
    private var inputError: String?
    private var reconnectAfter = 0.0
    private var sourceFailed = false

    var activeInput: AudioInput? { inputs.first { $0.uid == inputUID } }
    var signalSeen: Bool { session.hasReport }
    var hasControlLink: Bool { signalSeen && session.ready }
    var readout: Readout {
        if sleeping { return .sleeping }
        if !armed { return .standby }
        if !micAllowed { return .permission }
        if activeInput == nil { return .noInput }
        if inputError != nil { return .fault }
        if !signalSeen { return .searching }
        if !session.ready { return .release }
        if !keyboardAllowed { return .keyboard }
        if isTransmitting { return .transmitting }
        return .ready
    }

    var detail: String {
        switch readout {
        case .permission: "Allow microphone access to read the EP-2350’s audio signals."
        case .noInput: "Connect your USB audio adapter or choose an input below."
        case .standby: "Open Mic Setup on first use, then arm EP Talk."
        case .searching: "Power on the mic and release the paddle. First time? Open Mic Setup below."
        case .release: "Let the paddle return to rest before starting a take."
        case .ready: "Hold the paddle to dictate. Release it to finish."
        case .transmitting: "The shortcut is held. Release the paddle to finish."
        case .sleeping: "The link will reconnect when your Mac wakes."
        case .fault: inputError ?? "Reconnect the audio input."
        case .keyboard: "Allow Accessibility access to send the dictation shortcut."
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        armed = defaults.bool(forKey: "armed")
        inputUID = defaults.string(forKey: "audioInputUID") ?? ""
        shortcut = defaults.data(forKey: "shortcut")
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? Shortcut()
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func sleep() {
        sleeping = true
        stopCapture()
    }

    func wake() {
        sleeping = false
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stopCapture()
    }

    func refresh() {
        guard !sleeping else { return }
        if session.expire(at: ProcessInfo.processInfo.systemUptime) == .up { releaseShortcut() }
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if micAllowed != microphone { micAllowed = microphone }
        let accessibility = keyboard.hasAccess
        if keyboardAllowed != accessibility {
            keyboardAllowed = accessibility
            if !accessibility {
                releaseShortcut()
                _ = session.reset()
            }
        }
        let registered = SMAppService.mainApp.status == .enabled
        if registered != loginEnabled { loginEnabled = registered }
        let available = AudioInputs.list()
        if available != inputs { inputs = available }
        if inputUID.isEmpty, let input = available.first(where: { $0.name.localizedCaseInsensitiveContains("USB Advanced Audio") })
            ?? available.first(where: \.isUSB) {
            inputUID = input.uid
            return
        }
        guard armed, micAllowed, let input = activeInput else {
            if captureID != nil { stopCapture() }
            return
        }
        guard captureID != input.id || (receiver == nil && !sourceFailed) else { return }
        guard ProcessInfo.processInfo.systemUptime >= reconnectAfter else { return }
        stopCapture()
        connect(input)
    }

    private func connect(_ input: AudioInput) {
        captureID = input.id
        let token = generation
        let capture = AudioCapture { [weak self] event in
            guard let self, token == generation else { return }
            receive(event)
        }
        receiver = capture
        capture.start(device: input.id)
    }

    private func receive(_ event: AudioCaptureEvent) {
        switch event {
        case .listening:
            capturing = true
        case let .level(level):
            if abs(inputLevel - level) > 0.5 { inputLevel = level }
        case .lost:
            if session.loseSignal() == .up { releaseShortcut() }
        case let .failed(message, retry):
            let previousID = captureID
            stopCapture()
            inputError = message
            if retry {
                reconnectAfter = ProcessInfo.processInfo.systemUptime + 1.5
            } else {
                captureID = previousID
                sourceFailed = true
            }
        case let .report(report):
            guard !recordingShortcut, keyboardAllowed else {
                _ = session.observe(.init(paddle: report.paddle, orange: report.orange),
                                    at: ProcessInfo.processInfo.systemUptime)
                return
            }
            switch session.observe(report, at: ProcessInfo.processInfo.systemUptime) {
            case .down:
                isTransmitting = keyboard.press(shortcut)
                if !isTransmitting { notice = "Couldn’t send the shortcut. Check Accessibility access." }
            case .up:
                releaseShortcut()
            case nil:
                break
            }
        }
    }

    private func stopCapture() {
        generation = UUID()
        receiver?.stop()
        receiver = nil
        captureID = nil
        capturing = false
        sourceFailed = false
        inputError = nil
        reconnectAfter = 0
        inputLevel = -60
        _ = session.reset()
        releaseShortcut()
    }

    private func releaseShortcut() {
        keyboard.release()
        isTransmitting = false
    }

    func reconnect() {
        stopCapture()
        refresh()
    }

    func requestMicrophone() async {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        } else {
            openPrivacyPane("Privacy_Microphone")
        }
        refresh()
    }

    func requestKeyboard() {
        keyboard.requestAccess()
        if !keyboard.hasAccess { openPrivacyPane("Privacy_Accessibility") }
        refresh()
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    notice = "Approve EP Talk in Login Items & Extensions."
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            notice = "Couldn’t update the login item. \(error.localizedDescription)"
        }
        refresh()
    }

    func prepareMic(remove: Bool) async {
        guard !installing else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose FX MIC DISK"
        panel.message = "Connect the EP-2350 by USB-C and squeeze to power it on."
        panel.prompt = remove ? "Select for removal" : "Select mic"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        guard panel.runModal() == .OK, let volume = panel.url else { return }
        guard MicSetup.isMicVolume(volume) else {
            setupMessage = "Select the FX MIC DISK volume itself."
            return
        }
        let alert = NSAlert()
        alert.messageText = remove ? "Remove the handle signals?" : "Prepare this EP-2350?"
        alert.informativeText = remove
            ? "EP Talk removes only files that match its original signaling files."
            : "EP Talk backs up the mic’s files and adds a startup script and four signals. While installed, the mic’s effects and sample controls are repurposed for signaling."
        alert.addButton(withTitle: remove ? "Remove Signals" : "Back Up and Install")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let payload = Bundle.main.url(forResource: "Mic", withExtension: nil)
                ?? Bundle.module.url(forResource: "Mic", withExtension: nil) else {
            setupMessage = "The mic setup files are missing. Rebuild EP Talk."
            return
        }

        installing = true
        defer { installing = false }
        do {
            if remove {
                setupMessage = try await MicSetup.remove(from: volume, payload: payload)
            } else {
                setupMessage = try await MicSetup.install(on: volume, from: payload)
            }
        } catch {
            setupMessage = error.localizedDescription
        }
    }
}
