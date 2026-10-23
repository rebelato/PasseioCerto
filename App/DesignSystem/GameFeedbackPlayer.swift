import Foundation
#if os(iOS)
import AVFoundation
import UIKit
#endif

@MainActor final class GameFeedbackPlayer {
    #if os(iOS)
    private var player: AVAudioPlayer?
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private var sounds: [GameFeedback.Kind: Data] = [:]
    #endif
    func play(_ kind: GameFeedback.Kind, preferences: PlayerPreferences) {
        #if os(iOS)
        if preferences.hapticsEnabled {
            switch kind {
            case .action: impact.impactOccurred(intensity: 0.45)
            case .conflict: notification.notificationOccurred(.warning)
            case .victory: notification.notificationOccurred(.success)
            }
        }
        guard preferences.soundEnabled else { stop(); return }
        do {
            // Ambient mixes with other apps and respects Silent/lock:
            // https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            let data = sounds[kind] ?? tone(kind)
            sounds[kind] = data
            player?.stop() // never stack sounds from rapid taps
            player = try AVAudioPlayer(data: data)
            player?.volume = 0.18
            player?.play()
        } catch { player = nil } // visual feedback remains authoritative
        #endif
    }
    func stop() {
        #if os(iOS)
        player?.stop(); player = nil
        #endif
    }
    #if os(iOS)
    /// Tiny original PCM tones; no assets, network, speech or repeated barking.
    private func tone(_ kind: GameFeedback.Kind) -> Data {
        let notes: [Double]
        switch kind {
        case .action: notes = [660]
        case .conflict: notes = [240, 200]
        case .victory: notes = [523.25, 659.25, 783.99]
        }
        let rate = 22_050
        let count = Int(Double(rate) * 0.085)
        var samples = Data()
        for frequency in notes {
            for i in 0..<count {
                let envelope = sin(Double.pi * Double(i) / Double(count))
                let wave = sin(2 * Double.pi * frequency * Double(i) / Double(rate))
                var value = Int16(wave * envelope * 10_000).littleEndian
                withUnsafeBytes(of: &value) { samples.append(contentsOf: $0) }
            }
        }
        var data = Data()
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8); word(UInt32(36 + samples.count))
        data.append(contentsOf: "WAVEfmt ".utf8); word(UInt32(16))
        word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate*2))
        word(UInt16(2)); word(UInt16(16)); data.append(contentsOf: "data".utf8)
        word(UInt32(samples.count)); data.append(samples)
        return data
    }
    #endif
}
