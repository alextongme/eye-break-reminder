import Cocoa

class SettingsWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow

    var intervalSlider: NSSlider!
    var intervalValueLabel: NSTextField!
    var durationSlider: NSSlider!
    var durationValueLabel: NSTextField!
    var snoozeSlider: NSSlider!
    var snoozeValueLabel: NSTextField!
    var soundToggle: NSSwitch!
    var promptSoundPicker: NSPopUpButton!
    var completeSoundPicker: NSPopUpButton!
    var dndToggle: NSSwitch!
    var idleToggle: NSSwitch!
    var fullscreenToggle: NSSwitch!
    var launchToggle: NSSwitch!
    var longBreakToggle: NSSwitch!
    var longBreakEverySlider: NSSlider!
    var longBreakEveryLabel: NSTextField!
    var longBreakDurationSlider: NSSlider!
    var longBreakDurationLabel: NSTextField!

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 580),
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
        loadPreferences()
    }

    func buildUI() {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = Drac.background.cgColor

        var yOffset: CGFloat = 580 - 24

        func addSectionHeading(_ text: String) {
            let label = makeLabel(text, size: 16, weight: .bold, color: Drac.purple)
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 580 - yOffset)
            ])
            yOffset -= 28
        }

        func addRow(labelText: String, control: NSView, valueLabel: NSTextField? = nil) {
            let label = makeLabel(labelText, size: 13, weight: .regular, color: Drac.foreground)
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)

            control.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(control)

            let topOffset = 580 - yOffset

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
                label.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: topOffset + 18)
            ])

            if let vl = valueLabel {
                vl.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(vl)
                NSLayoutConstraint.activate([
                    vl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
                    vl.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: topOffset + 18),
                    control.trailingAnchor.constraint(equalTo: vl.leadingAnchor, constant: -8),
                    control.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: topOffset + 18),
                    control.widthAnchor.constraint(equalToConstant: 160)
                ])
            } else {
                NSLayoutConstraint.activate([
                    control.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
                    control.centerYAnchor.constraint(equalTo: contentView.topAnchor, constant: topOffset + 18)
                ])
            }

            yOffset -= 44
        }

        // Section 1: Timing
        addSectionHeading("Timing")

        intervalSlider = makeSlider(min: 5, max: 60, target: self, action: #selector(intervalChanged))
        intervalValueLabel = makeLabel("20 min", size: 13, weight: .regular, color: Drac.comment)
        intervalValueLabel.alignment = .right
        addRow(labelText: "Break interval", control: intervalSlider, valueLabel: intervalValueLabel)

        durationSlider = makeSlider(min: 10, max: 60, target: self, action: #selector(durationChanged))
        durationValueLabel = makeLabel("20 sec", size: 13, weight: .regular, color: Drac.comment)
        durationValueLabel.alignment = .right
        addRow(labelText: "Break duration", control: durationSlider, valueLabel: durationValueLabel)

        snoozeSlider = makeSlider(min: 1, max: 10, target: self, action: #selector(snoozeChanged))
        snoozeValueLabel = makeLabel("5 min", size: 13, weight: .regular, color: Drac.comment)
        snoozeValueLabel.alignment = .right
        addRow(labelText: "Snooze duration", control: snoozeSlider, valueLabel: snoozeValueLabel)

        yOffset -= 8

        // Section 2: Sounds
        addSectionHeading("Sounds")

        soundToggle = makeSwitch(target: self, action: #selector(soundToggleChanged))
        addRow(labelText: "Enable sounds", control: soundToggle)

        promptSoundPicker = NSPopUpButton()
        promptSoundPicker.addItems(withTitles: SoundManager.availableSounds)
        promptSoundPicker.target = self
        promptSoundPicker.action = #selector(promptSoundChanged)
        addRow(labelText: "Break prompt sound", control: promptSoundPicker)

        completeSoundPicker = NSPopUpButton()
        completeSoundPicker.addItems(withTitles: SoundManager.availableSounds)
        completeSoundPicker.target = self
        completeSoundPicker.action = #selector(completeSoundChanged)
        addRow(labelText: "Break complete sound", control: completeSoundPicker)

        yOffset -= 8

        // Section 3: Behavior
        addSectionHeading("Behavior")

        dndToggle = makeSwitch(target: self, action: #selector(dndToggleChanged))
        addRow(labelText: "Pause during Do Not Disturb", control: dndToggle)

        idleToggle = makeSwitch(target: self, action: #selector(idleToggleChanged))
        addRow(labelText: "Detect inactivity", control: idleToggle)

        fullscreenToggle = makeSwitch(target: self, action: #selector(fullscreenToggleChanged))
        addRow(labelText: "Fullscreen overlay", control: fullscreenToggle)

        launchToggle = makeSwitch(target: self, action: #selector(launchToggleChanged))
        addRow(labelText: "Launch at login", control: launchToggle)

        yOffset -= 8

        // Section 4: Long Breaks
        addSectionHeading("Long Breaks")

        longBreakToggle = makeSwitch(target: self, action: #selector(longBreakToggleChanged))
        addRow(labelText: "Enable long breaks", control: longBreakToggle)

        longBreakEverySlider = makeSlider(min: 2, max: 10, target: self, action: #selector(longBreakEveryChanged))
        longBreakEveryLabel = makeLabel("3 eye breaks", size: 13, weight: .regular, color: Drac.comment)
        longBreakEveryLabel.alignment = .right
        addRow(labelText: "Long break every", control: longBreakEverySlider, valueLabel: longBreakEveryLabel)

        longBreakDurationSlider = makeSlider(min: 1, max: 10, target: self, action: #selector(longBreakDurationChanged))
        longBreakDurationLabel = makeLabel("5 min", size: 13, weight: .regular, color: Drac.comment)
        longBreakDurationLabel.alignment = .right
        addRow(labelText: "Long break duration", control: longBreakDurationSlider, valueLabel: longBreakDurationLabel)
    }

    func loadPreferences() {
        let prefs = Preferences.shared

        let intervalMin = prefs.breakInterval / 60
        intervalSlider.intValue = Int32(intervalMin)
        intervalValueLabel.stringValue = "\(intervalMin) min"

        durationSlider.intValue = Int32(prefs.breakDuration)
        durationValueLabel.stringValue = "\(prefs.breakDuration) sec"

        let snoozeMin = prefs.snoozeDuration / 60
        snoozeSlider.intValue = Int32(snoozeMin)
        snoozeValueLabel.stringValue = "\(snoozeMin) min"

        soundToggle.state = prefs.soundEnabled ? .on : .off

        promptSoundPicker.selectItem(withTitle: prefs.promptSound)
        completeSoundPicker.selectItem(withTitle: prefs.completeSound)

        dndToggle.state = prefs.dndAware ? .on : .off
        idleToggle.state = prefs.idleDetectionEnabled ? .on : .off
        fullscreenToggle.state = prefs.fullscreenOverlay ? .on : .off
        launchToggle.state = prefs.launchAtLogin ? .on : .off

        longBreakToggle.state = prefs.longBreakEnabled ? .on : .off
        longBreakEverySlider.intValue = Int32(prefs.longBreakEveryN)
        longBreakEveryLabel.stringValue = "\(prefs.longBreakEveryN) eye breaks"

        let longBreakMin = prefs.longBreakDuration / 60
        longBreakDurationSlider.intValue = Int32(longBreakMin)
        longBreakDurationLabel.stringValue = "\(longBreakMin) min"
    }

    @objc func intervalChanged() {
        let val = Int(intervalSlider.intValue)
        intervalValueLabel.stringValue = "\(val) min"
        Preferences.shared.breakInterval = val * 60
    }

    @objc func durationChanged() {
        let val = Int(durationSlider.intValue)
        durationValueLabel.stringValue = "\(val) sec"
        Preferences.shared.breakDuration = val
    }

    @objc func snoozeChanged() {
        let val = Int(snoozeSlider.intValue)
        snoozeValueLabel.stringValue = "\(val) min"
        Preferences.shared.snoozeDuration = val * 60
    }

    @objc func soundToggleChanged() {
        Preferences.shared.soundEnabled = soundToggle.state == .on
    }

    @objc func promptSoundChanged() {
        guard let title = promptSoundPicker.selectedItem?.title else { return }
        Preferences.shared.promptSound = title
        SoundManager.shared.previewSound(title)
    }

    @objc func completeSoundChanged() {
        guard let title = completeSoundPicker.selectedItem?.title else { return }
        Preferences.shared.completeSound = title
        SoundManager.shared.previewSound(title)
    }

    @objc func dndToggleChanged() {
        Preferences.shared.dndAware = dndToggle.state == .on
    }

    @objc func idleToggleChanged() {
        Preferences.shared.idleDetectionEnabled = idleToggle.state == .on
    }

    @objc func fullscreenToggleChanged() {
        Preferences.shared.fullscreenOverlay = fullscreenToggle.state == .on
    }

    @objc func launchToggleChanged() {
        Preferences.shared.launchAtLogin = launchToggle.state == .on
    }

    @objc func longBreakToggleChanged() {
        Preferences.shared.longBreakEnabled = longBreakToggle.state == .on
    }

    @objc func longBreakEveryChanged() {
        let val = Int(longBreakEverySlider.intValue)
        longBreakEveryLabel.stringValue = "\(val) eye breaks"
        Preferences.shared.longBreakEveryN = val
    }

    @objc func longBreakDurationChanged() {
        let val = Int(longBreakDurationSlider.intValue)
        longBreakDurationLabel.stringValue = "\(val) min"
        Preferences.shared.longBreakDuration = val * 60
    }

    func windowWillClose(_ notification: Notification) {
        // Don't quit the app — just hide
    }
}

// MARK: - Factories

private func makeSwitch(target: AnyObject?, action: Selector?) -> NSSwitch {
    let s = NSSwitch()
    s.translatesAutoresizingMaskIntoConstraints = false
    s.target = target
    s.action = action
    return s
}

private func makeSlider(min: Double, max: Double, target: AnyObject?, action: Selector?) -> NSSlider {
    let s = NSSlider(value: min, minValue: min, maxValue: max, target: target, action: action)
    s.translatesAutoresizingMaskIntoConstraints = false
    s.isContinuous = true
    return s
}
