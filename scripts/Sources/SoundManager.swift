import Cocoa

class SoundManager {
    static let shared = SoundManager()

    // macOS system sounds available for user selection
    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Pop",
        "Purr", "Sosumi", "Submarine", "Tink",
    ]

    // Play system sounds via afplay to avoid NSSound triggering mic permission on macOS 26
    private func play(_ name: String) {
        guard SoundManager.availableSounds.contains(name) else { return }
        let path = "/System/Library/Sounds/\(name).aiff"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        task.arguments = [path]
        try? task.run()
    }

    func playPromptSound() {
        guard Preferences.shared.soundEnabled else { return }
        play(Preferences.shared.promptSound)
    }

    func playCompleteSound() {
        guard Preferences.shared.soundEnabled else { return }
        play(Preferences.shared.completeSound)
    }

    func playMilestoneSound() {
        guard Preferences.shared.soundEnabled else { return }
        play("Hero")
    }

    func playSound(_ name: String) {
        guard Preferences.shared.soundEnabled else { return }
        play(name)
    }

    // Always plays regardless of soundEnabled — used for settings preview
    func previewSound(_ name: String) {
        play(name)
    }
}
