import SwiftUI

enum ConsolePalette {
    static let chassis = Color(red: 0.094, green: 0.118, blue: 0.141)
    static let screen = Color(red: 0.051, green: 0.071, blue: 0.086)
    static let rule = Color(red: 0.196, green: 0.231, blue: 0.263)
    static let text = Color(red: 0.937, green: 0.949, blue: 0.953)
    static let secondary = Color(red: 0.64, green: 0.70, blue: 0.75)
    static let ready = Color(red: 0.61, green: 0.85, blue: 0.75)
    static let signal = Color(red: 1.00, green: 0.72, blue: 0.44)
}

struct ConsoleView: View {
    @Bindable var model: ConsoleModel
    @State private var showingSetup = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("EP Talk")
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(-1.0)
                        .accessibilityAddTraits(.isHeader)
                    Text("EP-2350 push-to-talk")
                        .font(.system(size: 13))
                        .foregroundStyle(ConsolePalette.secondary)
                }
                Spacer()
                Button {
                    model.armed.toggle()
                } label: {
                    Label(model.armed ? "Disarm" : "Arm", systemImage: "power")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(minWidth: 83, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.armed ? ConsolePalette.rule : ConsolePalette.ready)
                .foregroundStyle(model.armed ? ConsolePalette.text : ConsolePalette.screen)
                .help(model.armed ? "Stop listening and release the shortcut" : "Listen for the mic’s handle signals")
            }
            .padding(.bottom, 24)

            TelemetryView(readout: model.readout, detail: model.detail, level: model.inputLevel,
                          capturing: model.capturing, link: model.hasControlLink)
                .padding(.bottom, 17)

            configuration
            if !model.micAllowed || !model.keyboardAllowed {
                permissionActions
            }
            footer
        }
        .padding(.horizontal, 25)
        .padding(.top, 37)
        .padding(.bottom, 20)
        .foregroundStyle(ConsolePalette.text)
        .frame(minWidth: 510)
        .background(ConsolePalette.chassis)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSetup) { SetupView(model: model) }
        .alert("EP Talk", isPresented: Binding(
            get: { model.notice != nil },
            set: { if !$0 { model.notice = nil } }
        )) {
            Button("OK") { model.notice = nil }
        } message: {
            Text(model.notice ?? "")
        }
    }

    private var configuration: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Audio input", systemImage: "waveform")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Menu {
                    if model.inputs.isEmpty { Text("No audio inputs available") }
                    ForEach(model.inputs) { input in
                        Button {
                            model.inputUID = input.uid
                        } label: {
                            if input.uid == model.inputUID {
                                Label(input.name, systemImage: "checkmark")
                            } else {
                                Text(input.name)
                            }
                        }
                    }
                    Divider()
                    Button("Refresh Inputs") { model.reconnect() }
                } label: {
                    Text(model.activeInput?.name ?? "Choose input")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 252, alignment: .trailing)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Audio input")
                .accessibilityValue(model.activeInput?.name ?? "None selected")
            }
            .frame(minHeight: 43)

            Divider().overlay(ConsolePalette.rule)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Dictation shortcut", systemImage: "keyboard")
                        .font(.system(size: 13, weight: .medium))
                    Text("Match the hold-to-talk shortcut in Handy or your dictation app.")
                        .foregroundStyle(ConsolePalette.secondary)
                        .font(.system(size: 11))
                }
                Spacer(minLength: 12)
                Button(model.shortcut.label) { model.recordingShortcut = true }
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .accessibilityLabel("Record dictation shortcut")
                    .accessibilityValue(model.shortcut.spokenLabel)
                    .help("Record a new dictation shortcut")
            }
            .frame(minHeight: 58)

            Divider().overlay(ConsolePalette.rule)
        }
        .sheet(isPresented: $model.recordingShortcut) {
            RecordShortcutView { shortcut in
                if let shortcut { model.shortcut = shortcut }
                model.recordingShortcut = false
            }
        }
    }

    private var permissionActions: some View {
        HStack(spacing: 8) {
            if !model.micAllowed {
                Button("Allow Microphone") { Task { await model.requestMicrophone() } }
            }
            if !model.keyboardAllowed {
                Button("Allow Accessibility") { model.requestKeyboard() }
            }
            Spacer()
        }
        .controlSize(.small)
        .padding(.top, 13)
    }

    private var footer: some View {
        HStack {
            Button {
                showingSetup = true
            } label: {
                Label("Mic Setup", systemImage: "wrench.and.screwdriver")
            }
            .help("Install or remove the signals on your EP-2350")
            Spacer()
            Toggle("Open at login", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                .toggleStyle(.checkbox)
        }
        .controlSize(.small)
        .padding(.top, 14)
        .foregroundStyle(ConsolePalette.secondary)
    }
}
