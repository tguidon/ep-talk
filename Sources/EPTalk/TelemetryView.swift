import SwiftUI

struct TelemetryView: View {
    let readout: ConsoleModel.Readout
    let detail: String
    let level: Double
    let capturing: Bool
    let link: Bool

    private var lamp: Color {
        switch readout {
        case .transmitting: ConsolePalette.signal
        case .ready: ConsolePalette.ready
        case .standby, .sleeping: ConsolePalette.secondary
        default: ConsolePalette.signal.opacity(0.78)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Circle()
                    .fill(lamp)
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)
                Text(readout.title)
                    .font(.system(size: 28, weight: .medium))
                    .tracking(-0.45)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Image(systemName: "link")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(link ? ConsolePalette.ready : ConsolePalette.secondary)
                    .accessibilityLabel(link ? "Handle signal linked" : "Handle signal unavailable")
            }

            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(ConsolePalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .frame(minHeight: 40, alignment: .topLeading)

            Rectangle()
                .fill(ConsolePalette.rule)
                .frame(height: 1)
                .padding(.vertical, 13)
                .accessibilityHidden(true)

            HStack {
                Text("INPUT LEVEL")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.05)
                Spacer()
                Text(capturing && level > -60 ? "\(Int(level.rounded())) dBFS" : "— dBFS")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(ConsolePalette.secondary)
            .padding(.bottom, 9)
            .accessibilityHidden(true)

            InputMeter(level: level, capturing: capturing)
        }
        .padding(18)
        .background(ConsolePalette.screen, in: RoundedRectangle(cornerRadius: 13))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(ConsolePalette.rule, lineWidth: 1).allowsHitTesting(false) }
    }
}

private struct InputMeter: View {
    let level: Double
    let capturing: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<32) { division in
                let lit = capturing && level > -60 + Double(division) * 60 / 32
                RoundedRectangle(cornerRadius: 1.3)
                    .fill(lit ? (division >= 27 ? ConsolePalette.signal : ConsolePalette.ready) : ConsolePalette.rule)
                    .frame(height: 9)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Audio input level")
        .accessibilityValue(capturing && level > -60 ? "\(Int(level.rounded())) decibels" : "Silent")
    }
}
