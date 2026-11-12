import AVFoundation
import FrenchCore
import Observation
import os

/// Reads French aloud with the system voice.
@MainActor
@Observable
final class Speech {
    /// Set when the device has no French voice; shown as an alert by the root view.
    var failure: String?

    private let synthesizer = AVSpeechSynthesizer()
    private let log = Logger(subsystem: "io.github.oniluni.french", category: "speech")

    init() {
        do {
            // Playback, so that the ring switch does not silence a pronunciation app.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        } catch {
            log.error("Cannot set the audio session category: \(String(describing: error), privacy: .public)")
        }
    }

    /// - Parameter text: French, plain or with pronunciation marks.
    func speak(_ text: String) {
        guard let voice = AVSpeechSynthesisVoice(language: "fr-FR") else {
            failure = "На устройстве нет французского голоса. Добавьте его в Настройках: Универсальный доступ → Устный контент → Голоса → Французский."
            return
        }
        let utterance = AVSpeechUtterance(string: Markup.plain(text))
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}
