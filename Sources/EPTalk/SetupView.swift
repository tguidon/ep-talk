import SwiftUI

struct SetupView: View {
    let model: ConsoleModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Mic Setup")
                .font(.system(size: 25, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text("The handle sends tones through the curly cable so EP Talk can detect a squeeze and release.")
                .foregroundStyle(ConsolePalette.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("1. Plug the mic’s USB-C port into your Mac, then squeeze to power it on.")
                Text("2. Choose Prepare Mic and select FX MIC DISK. EP Talk backs up the mic’s files before installing the signals.")
                Text("3. Eject the disk in Finder, disconnect USB-C, and replace the cover. Use the curly cable and your Sabrent adapter from then on.")
            }
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)

            if model.installing {
                ProgressView("Working with FX MIC DISK…")
                    .controlSize(.small)
            }
            if let message = model.setupMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(ConsolePalette.signal)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Remove Signals") { Task { await model.prepareMic(remove: true) } }
                    .disabled(model.installing)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(model.installing)
                Button("Prepare Mic…") { Task { await model.prepareMic(remove: false) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.installing)
            }
        }
        .padding(24)
        .frame(width: 465)
        .foregroundStyle(ConsolePalette.text)
        .background(ConsolePalette.chassis)
        .interactiveDismissDisabled(model.installing)
    }
}
