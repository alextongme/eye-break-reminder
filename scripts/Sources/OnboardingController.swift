import Cocoa

class OnboardingController: NSObject, NSWindowDelegate {
    static let didCompleteNotification = Notification.Name("CountTongulaOnboardingComplete")

    let window: NSWindow
    var intervalSlider: NSSlider!
    var intervalLabel: NSTextField!
    var durationSlider: NSSlider!
    var durationLabel: NSTextField!

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.backgroundColor = Drac.background
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildUI()
    }

    func buildUI() {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Drac.background.cgColor

        // Mascot image
        let mascotImage: NSImageView
        let imagePath = assetPath("dracula.png")
        if let img = NSImage(contentsOfFile: imagePath) {
            mascotImage = NSImageView(image: img)
        } else if let img = NSImage(contentsOfFile: assetPath("dracula.svg")) {
            mascotImage = NSImageView(image: img)
        } else {
            mascotImage = NSImageView()
        }
        mascotImage.translatesAutoresizingMaskIntoConstraints = false
        mascotImage.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(mascotImage)

        // Welcome heading
        let headingLabel = makeLabel("Welcome to Count Tongula's Eye Break", size: 20, weight: .bold, color: Drac.purple)
        headingLabel.alignment = .center
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headingLabel)

        // Rule explanation
        let ruleText = "Every 20 minutes, take a 20-second break\nand look at something 20 feet away.\n\nThe Count will remind you."
        let ruleLabel = makeLabel(ruleText, size: 14, weight: .regular, color: Drac.foreground)
        ruleLabel.alignment = .center
        ruleLabel.maximumNumberOfLines = 0
        ruleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(ruleLabel)

        // Break interval row
        let intervalRowLabel = makeLabel("Break every", size: 13, weight: .regular, color: Drac.foreground)
        intervalRowLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(intervalRowLabel)

        intervalSlider = NSSlider(value: 20, minValue: 5, maxValue: 60, target: self, action: #selector(intervalChanged))
        intervalSlider.translatesAutoresizingMaskIntoConstraints = false
        intervalSlider.isContinuous = true
        contentView.addSubview(intervalSlider)

        intervalLabel = makeLabel("20 min", size: 13, weight: .regular, color: Drac.comment)
        intervalLabel.alignment = .right
        intervalLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(intervalLabel)

        // Break duration row
        let durationRowLabel = makeLabel("Break duration", size: 13, weight: .regular, color: Drac.foreground)
        durationRowLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationRowLabel)

        durationSlider = NSSlider(value: 20, minValue: 10, maxValue: 60, target: self, action: #selector(durationChanged))
        durationSlider.translatesAutoresizingMaskIntoConstraints = false
        durationSlider.isContinuous = true
        contentView.addSubview(durationSlider)

        durationLabel = makeLabel("20 sec", size: 13, weight: .regular, color: Drac.comment)
        durationLabel.alignment = .right
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)

        // Get Started button
        let startButton = HoverButton(
            "Begin the Night Watch",
            bg: Drac.purple,
            hover: Drac.pink,
            fg: Drac.background,
            target: self,
            action: #selector(getStarted)
        )
        startButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(startButton)

        // Skip link
        let skipButton = HoverButton(
            "I'll configure later",
            bg: Drac.background,
            hover: Drac.background,
            fg: Drac.comment,
            target: self,
            action: #selector(skipTapped)
        )
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(skipButton)

        NSLayoutConstraint.activate([
            // Mascot: 120x120 centered near top
            mascotImage.widthAnchor.constraint(equalToConstant: 120),
            mascotImage.heightAnchor.constraint(equalToConstant: 120),
            mascotImage.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            mascotImage.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

            // Heading below mascot
            headingLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            headingLabel.topAnchor.constraint(equalTo: mascotImage.bottomAnchor, constant: 16),
            headingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            headingLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            // Rule text below heading
            ruleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            ruleLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 12),
            ruleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            ruleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),

            // Break interval row
            intervalRowLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            intervalRowLabel.centerYAnchor.constraint(equalTo: intervalSlider.centerYAnchor),

            intervalLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            intervalLabel.centerYAnchor.constraint(equalTo: intervalSlider.centerYAnchor),
            intervalLabel.widthAnchor.constraint(equalToConstant: 60),

            intervalSlider.topAnchor.constraint(equalTo: ruleLabel.bottomAnchor, constant: 24),
            intervalSlider.trailingAnchor.constraint(equalTo: intervalLabel.leadingAnchor, constant: -8),
            intervalSlider.leadingAnchor.constraint(equalTo: intervalRowLabel.trailingAnchor, constant: 12),

            // Break duration row
            durationRowLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            durationRowLabel.centerYAnchor.constraint(equalTo: durationSlider.centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            durationLabel.centerYAnchor.constraint(equalTo: durationSlider.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 60),

            durationSlider.topAnchor.constraint(equalTo: intervalSlider.bottomAnchor, constant: 16),
            durationSlider.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            durationSlider.leadingAnchor.constraint(equalTo: durationRowLabel.trailingAnchor, constant: 12),

            // Get Started button
            startButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            startButton.topAnchor.constraint(equalTo: durationSlider.bottomAnchor, constant: 32),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 44),

            // Skip link
            skipButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            skipButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 12),
        ])
    }

    @objc func getStarted() {
        let intervalMin = Int(intervalSlider.intValue)
        let durationSec = Int(durationSlider.intValue)
        Preferences.shared.breakInterval = intervalMin * 60
        Preferences.shared.breakDuration = durationSec
        Preferences.shared.hasCompletedOnboarding = true
        window.close()
        NotificationCenter.default.post(name: OnboardingController.didCompleteNotification, object: nil)
    }

    @objc func skipTapped() {
        Preferences.shared.hasCompletedOnboarding = true
        window.close()
        NotificationCenter.default.post(name: OnboardingController.didCompleteNotification, object: nil)
    }

    @objc func intervalChanged() {
        let val = Int(intervalSlider.intValue)
        intervalLabel.stringValue = "\(val) min"
    }

    @objc func durationChanged() {
        let val = Int(durationSlider.intValue)
        durationLabel.stringValue = "\(val) sec"
    }

    func windowWillClose(_ notification: Notification) {
        // Mark onboarding complete if closed via window button without explicitly choosing
        if !Preferences.shared.hasCompletedOnboarding {
            Preferences.shared.hasCompletedOnboarding = true
            NotificationCenter.default.post(name: OnboardingController.didCompleteNotification, object: nil)
        }
    }
}
