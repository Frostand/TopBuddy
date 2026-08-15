import SwiftUI

struct NotchFocusPageView: View {
    @ObservedObject var focus: FocusUtilityStore

    var body: some View {
        HStack(spacing: 18) {
            VStack(spacing: 12) {
                Text(focus.isEyeBreak ? "LOOK AWAY" : focus.preset.title.uppercased())
                    .font(.caption.weight(.black))
                    .foregroundStyle(focus.isEyeBreak ? .green : .cyan)
                Text(focus.timeLabel)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 8) {
                    Button(focus.isRunning ? "Pause" : "Start", systemImage: focus.isRunning ? "pause.fill" : "play.fill") {
                        focus.toggleTimer()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reset", systemImage: "arrow.counterclockwise") { focus.resetTimer() }
                        .buttonStyle(.bordered)
                }
                .controlSize(.regular)
            }
            .frame(maxWidth: .infinity)

            Divider().overlay(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 12) {
                Label("QUICK UTILITIES", systemImage: "switch.2")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.purple)

                Picker("Timer", selection: Binding(
                    get: { focus.preset },
                    set: { focus.select($0) }
                )) {
                    ForEach(FocusTimerPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(isOn: Binding(
                    get: { focus.isCaffeinated },
                    set: { _ in focus.toggleCaffeinate() }
                )) {
                    Label("Keep Mac awake", systemImage: "cup.and.heat.waves.fill")
                }
                .toggleStyle(.switch)

                Text(focus.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(3)

                Text("20-20-20: after 20 minutes, look 20 feet away for 20 seconds.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.42))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    }
}
