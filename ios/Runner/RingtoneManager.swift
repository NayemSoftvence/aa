import AVFoundation
import Foundation

class RingtoneManager: NSObject, AVAudioPlayerDelegate {
    private var audioPlayer: AVAudioPlayer?

    func playRingtone() {
        do {
            // Configure audio session for ringtone
            try AVAudioSession.sharedInstance().setCategory(
                .soloAmbient,
                mode: .default,
                options: [.duckOthers, .defaultToSpeaker]
            )
            try AVAudioSession.sharedInstance().setActive(
                true, options: .notifyOthersOnDeactivation)

            // Get the system ringtone sound
            guard let soundURL = URL(fileURLWithPath: "/System/Library/Sounds/Beacon.aiff") as URL?
            else {
                print("Could not load ringtone file")
                return
            }

            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1  // Loop indefinitely
            audioPlayer?.play()
            print("Ringtone started")
        } catch {
            print("Error playing ringtone: \(error)")
        }
    }

    func stopRingtone() {
        audioPlayer?.stop()
        audioPlayer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation)
            print("Ringtone stopped")
        } catch {
            print("Error stopping ringtone: \(error)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Restart playing if it finished
        if flag && audioPlayer?.numberOfLoops == -1 {
            audioPlayer?.play()
        }
    }
}
