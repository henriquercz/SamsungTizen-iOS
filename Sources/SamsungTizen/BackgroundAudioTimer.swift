import Foundation
import AVFoundation

/// Manages a zero-volume silent audio session so iOS does not suspend the sleep timer
/// when the user locks their phone or switches apps.
@MainActor
final class BackgroundAudioTimer {
    static let shared = BackgroundAudioTimer()
    private var player: AVAudioPlayer?
    private(set) var isActive = false

    private init() {}

    func start() {
        guard !isActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            // Generate a 1-second silent audio buffer or tiny WAV in memory
            if let data = Self.generateSilentWAVData() {
                player = try AVAudioPlayer(data: data)
                player?.numberOfLoops = -1 // Loop infinitely until cancelled
                player?.volume = 0.0 // Completely silent
                player?.play()
            }
            isActive = true
        } catch {
            // Fallback: timer continues in memory
            isActive = true
        }
    }

    func stop() {
        guard isActive else { return }
        player?.stop()
        player = nil
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        isActive = false
    }

    /// Generates a valid 1-second 8kHz mono silent PCM WAV in memory
    private static func generateSilentWAVData() -> Data? {
        let sampleRate: UInt32 = 8000
        let numSamples: UInt32 = 8000
        let byteRate = sampleRate * 2
        let dataSize = numSamples * 2
        let totalSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        header.append(contentsOf: withUnsafeBytes(of: totalSize.littleEndian) { Array($0) })
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // Mono
        header.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        let silence = Data(count: Int(dataSize))
        return header + silence
    }
}
