import Cocoa

struct Quotes {
    // Shown on break prompt screen
    static let prompt = [
        "I am Count Tongula, and I bid you...\nrest your eyes.",
        "Listen to them, the children of the night.\nBut first — rest your eyes.",
        "I never drink... coffee\nwithout an eye break.",
        "There are far worse things awaiting you\nthan death... like screen fatigue.",
        "To rest, to truly rest your eyes —\nthat must be glorious.",
        "Welcome. I bid you...\nlook away from your screen.",
        "The strength of the vampire is that\nno one believes in eye breaks.",
        "Enter freely and of your own will —\ninto this eye break.",
        "We are in Transylvania, and Transylvania\nis not England. Rest your eyes.",
        "I have crossed oceans of time\nto remind you: rest your eyes.",
    ]

    // Shown during the 20-second countdown
    static let countdown = [
        "Gaze into the distance, mortal!",
        "The night calls — look toward it.",
        "Even vampires rest their eyes.",
        "Peer into the darkness beyond...",
        "Let your eyes wander the shadows.",
        "Stare into the void. It stares back.",
        "The distant horizon awaits your gaze.",
        "Look away... if you dare.",
    ]

    // Shown when break finishes
    static let complete = [
        "Count Tongula is pleased.",
        "Excellent. Your eyes serve you well.",
        "The night rewards those who rest.",
        "You have earned the Count's approval.",
        "Your devotion to eye health is... noted.",
        "The vampire nods approvingly.",
        "Most impressive, mortal.",
        "Count Tongula himself would be proud.",
    ]

    // Shown during the longer 5-minute stretch break
    static let longBreak = [
        "Rise from your coffin, mortal. Walk among the living.",
        "The night beckons — stretch your limbs and stalk the halls.",
        "Even the undead must move. Stand. Reach for the darkness above.",
        "Count Tongula commands you: roll your shoulders, wake your bones.",
        "You have been hunched over that machine long enough. The Count insists you stretch.",
        "The bats take flight each night — let your arms do the same. Stretch them wide.",
        "Walk to a window. Survey your domain. Return when the blood flows freely again.",
        "Your neck is stiff as a crypt door. Tilt it left... now right. The Count approves.",
    ]

    // Milestone unlock messages keyed by streak count
    static let milestones: [Int: String] = [
        5:   "5 breaks without fail! The Count promotes you to Familiar.",
        10:  "10 breaks completed. You have earned the title: Servant of the Night.",
        25:  "25 breaks! The Count grants you access to his inner sanctum. You are now a Thrall.",
        50:  "50 breaks observed. Remarkable dedication. The Count considers making you immortal.",
        100: "100 breaks. You have transcended mortality. Welcome... to the order of Count Tongula.",
    ]

    static func random(_ list: [String]) -> String {
        guard !list.isEmpty else { return "" }
        return list[Int.random(in: 0..<list.count)]
    }
}
