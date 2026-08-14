import AVFoundation

@MainActor
final class SpeechController {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let spokenText = String(text.prefix(800)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spokenText.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: spokenText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.08
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
