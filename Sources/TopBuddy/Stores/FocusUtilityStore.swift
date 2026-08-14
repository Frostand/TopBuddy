import Foundation

@MainActor
final class FocusUtilityStore: ObservableObject {
    @Published private(set) var preset: FocusTimerPreset = .focus25
    @Published private(set) var remainingSeconds = FocusTimerPreset.focus25.initialSeconds
    @Published private(set) var isRunning = false
    @Published private(set) var isEyeBreak = false
    @Published private(set) var isCaffeinated = false
    @Published var statusMessage = "Choose a timer and start when you are ready."

    private var timer: Timer?
    private var caffeinateProcess: Process?

    func select(_ preset: FocusTimerPreset) {
        stopTimer()
        self.preset = preset
        remainingSeconds = preset.initialSeconds
        isEyeBreak = false
        statusMessage = preset == .eyeBreak
            ? "Twenty minutes of work, then look 20 feet away for 20 seconds."
            : "\(preset.title) is ready."
    }

    func toggleTimer() {
        isRunning ? pauseTimer() : startTimer()
    }

    func resetTimer() {
        stopTimer()
        remainingSeconds = preset.initialSeconds
        isEyeBreak = false
        statusMessage = "\(preset.title) reset."
    }

    func toggleCaffeinate() {
        if isCaffeinated {
            caffeinateProcess?.terminate()
            caffeinateProcess = nil
            isCaffeinated = false
            statusMessage = "Caffeinate stopped. Normal sleep settings are active."
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-di", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        do {
            try process.run()
            caffeinateProcess = process
            isCaffeinated = true
            statusMessage = "Caffeinate is keeping the display and Mac awake until you turn it off."
        } catch {
            statusMessage = "Caffeinate could not start: \(error.localizedDescription)"
        }
    }

    var timeLabel: String {
        String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60)
    }

    private func startTimer() {
        guard remainingSeconds > 0 else { resetTimer(); return }
        isRunning = true
        statusMessage = isEyeBreak ? "Look 20 feet away." : "Timer running."
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        statusMessage = "Timer paused with \(timeLabel) remaining."
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func tick() {
        guard remainingSeconds > 0 else { completePhase(); return }
        remainingSeconds -= 1
        if remainingSeconds == 0 { completePhase() }
    }

    private func completePhase() {
        if preset == .eyeBreak, !isEyeBreak {
            isEyeBreak = true
            remainingSeconds = 20
            statusMessage = "Eye break: look 20 feet away for 20 seconds."
            return
        }
        stopTimer()
        statusMessage = isEyeBreak ? "Eye break complete." : "Focus timer complete."
    }
}
