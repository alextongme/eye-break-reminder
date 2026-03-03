import Cocoa

// MARK: - Enums & Protocol

enum BreakType {
    case eye   // 20-second eye break
    case long  // 5-minute stretch break
}

enum BreakResult {
    case completed
    case skipped
    case snoozed
}

protocol BreakWindowDelegate: AnyObject {
    func breakDidFinish(type: BreakType, result: BreakResult)
}

// MARK: - BreakWindowController

class BreakWindowController: NSObject, NSWindowDelegate {

    weak var delegate: BreakWindowDelegate?
    let breakType: BreakType
    let allowSnooze: Bool

    let window: NSWindow
    var overlayWindows: [NSWindow] = []

    let mascot: NSImageView
    let heading: NSTextField
    let body: NSTextField
    let detail: NSTextField
    let countdownLbl: NSTextField
    let countdownSub: NSTextField
    let progressBar: ProgressBarView
    var primaryBtn: HoverButton!
    var secondaryBtn: HoverButton!
    var dismissBtn: HoverLink!

    var primaryCenterX: NSLayoutConstraint!
    var primaryPaired: NSLayoutConstraint!

    var secondsLeft: Int
    var timer: Timer?
    private var hasReportedResult = false

    private let totalDuration: Int

    // MARK: - Init

    init(type: BreakType, allowSnooze: Bool = true) {
        self.breakType = type
        self.allowSnooze = allowSnooze

        let duration = (type == .eye)
            ? Preferences.shared.breakDuration
            : Preferences.shared.longBreakDuration
        self.secondsLeft = duration
        self.totalDuration = duration

        // Main window
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 480),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.appearance = NSAppearance(named: .darkAqua)
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = Drac.background
        win.isMovableByWindowBackground = false
        win.hasShadow = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.window = win

        // Mascot
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyDown
        if let img = NSImage(contentsOfFile: assetPath("dracula.png"))
                  ?? NSImage(contentsOfFile: assetPath("dracula.svg")) {
            iv.image = img
        }
        self.mascot = iv

        // Labels
        self.heading      = makeLabel("", size: 22, weight: .bold, color: Drac.purple)
        self.body         = makeLabel("", size: 17, weight: .regular, color: Drac.foreground)
        self.detail       = makeLabel("", size: 15, weight: .medium, color: Drac.cyan)
        self.countdownLbl = makeLabel("", size: 80, weight: .heavy, color: Drac.green)
        self.countdownSub = makeLabel("", size: 14, weight: .regular, color: Drac.comment)
        self.progressBar  = ProgressBarView()

        super.init()

        win.delegate = self

        // Buttons
        primaryBtn = HoverButton(
            "Start Break",
            bg: Drac.purple,
            hover: Drac.pink,
            fg: Drac.foreground,
            target: self,
            action: #selector(primaryTapped)
        )
        secondaryBtn = HoverButton(
            "Snooze 5 min",
            bg: Drac.currentLine,
            hover: Drac.comment,
            fg: Drac.foreground,
            target: self,
            action: #selector(snoozeTapped)
        )
        dismissBtn = HoverLink(
            "Not now — remind me later",
            color: Drac.comment,
            hover: Drac.pink,
            size: 13,
            target: self,
            action: #selector(dismissTapped)
        )

        layout()
        showPrompt()

        // Position on screen containing mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
        if let screen = targetScreen {
            let sf = screen.visibleFrame
            let wf = win.frame
            let x = sf.minX + (sf.width - wf.width) / 2
            let y = sf.minY + (sf.height - wf.height) / 2
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        startMascotAnimation()

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout

    private func layout() {
        guard let cv = window.contentView else { return }
        cv.wantsLayer = true
        cv.layer?.backgroundColor = Drac.background.cgColor

        heading.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        detail.translatesAutoresizingMaskIntoConstraints = false
        countdownLbl.translatesAutoresizingMaskIntoConstraints = false
        countdownSub.translatesAutoresizingMaskIntoConstraints = false
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        primaryBtn.translatesAutoresizingMaskIntoConstraints = false
        secondaryBtn.translatesAutoresizingMaskIntoConstraints = false
        dismissBtn.translatesAutoresizingMaskIntoConstraints = false

        for v in [mascot, heading, body, detail, countdownLbl, countdownSub,
                  progressBar, primaryBtn!, secondaryBtn!, dismissBtn!] as [NSView] {
            cv.addSubview(v)
        }

        // Multi-line labels — set preferredMaxLayoutWidth so text wraps
        // instead of expanding the window (460 - 64px padding = 396)
        for lbl in [heading, body, detail, countdownSub] {
            lbl.maximumNumberOfLines = 0
            lbl.lineBreakMode = .byWordWrapping
            lbl.preferredMaxLayoutWidth = 396
            lbl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        NSLayoutConstraint.activate([
            // Mascot
            mascot.topAnchor.constraint(equalTo: cv.topAnchor, constant: 36),
            mascot.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            mascot.widthAnchor.constraint(equalToConstant: 110),
            mascot.heightAnchor.constraint(equalToConstant: 110),

            // Heading
            heading.topAnchor.constraint(equalTo: mascot.bottomAnchor, constant: 36),
            heading.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 32),
            heading.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -32),

            // Body
            body.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 14),
            body.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 40),
            body.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -40),

            // Detail
            detail.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 14),
            detail.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 40),
            detail.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -40),

            // Countdown label
            countdownLbl.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8),
            countdownLbl.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            // Countdown sub
            countdownSub.topAnchor.constraint(equalTo: countdownLbl.bottomAnchor, constant: -2),
            countdownSub.centerXAnchor.constraint(equalTo: cv.centerXAnchor),

            // Progress bar
            progressBar.topAnchor.constraint(equalTo: countdownSub.bottomAnchor, constant: 14),
            progressBar.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
            progressBar.widthAnchor.constraint(equalToConstant: 300),
            progressBar.heightAnchor.constraint(equalToConstant: 6),

            // Primary button
            primaryBtn.bottomAnchor.constraint(equalTo: dismissBtn.topAnchor, constant: -14),
            primaryBtn.widthAnchor.constraint(equalToConstant: 160),
            primaryBtn.heightAnchor.constraint(equalToConstant: 42),

            // Secondary button
            secondaryBtn.bottomAnchor.constraint(equalTo: dismissBtn.topAnchor, constant: -14),
            secondaryBtn.leadingAnchor.constraint(equalTo: cv.centerXAnchor, constant: 8),
            secondaryBtn.widthAnchor.constraint(equalToConstant: 160),
            secondaryBtn.heightAnchor.constraint(equalToConstant: 42),

            // Dismiss link
            dismissBtn.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -18),
            dismissBtn.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
        ])

        // Paired layout: two buttons side by side
        primaryPaired = primaryBtn.trailingAnchor.constraint(equalTo: cv.centerXAnchor, constant: -8)
        // Centered layout: single button
        primaryCenterX = primaryBtn.centerXAnchor.constraint(equalTo: cv.centerXAnchor)
    }

    // MARK: - Screen States

    func showPrompt() {
        heading.stringValue = (breakType == .long)
            ? "Time for a stretch break!"
            : "Time for an eye break!"
        heading.textColor = Drac.purple

        if breakType == .long {
            let longMin = Preferences.shared.longBreakDuration / 60
            body.stringValue = "Stand up, stretch, and move around."
            detail.stringValue = "This is a \(longMin)-minute break. Ready?"
        } else {
            body.stringValue = "Look at something 20 feet away for 20 seconds."
            detail.stringValue = ""
        }

        body.isHidden = false
        detail.isHidden = false
        countdownLbl.isHidden = true
        countdownSub.isHidden = true
        progressBar.isHidden = true

        primaryBtn.setLabel("Start Break")
        primaryBtn.isHidden = false

        dismissBtn.isHidden = false

        if allowSnooze {
            secondaryBtn.isHidden = false
            primaryCenterX.isActive = false
            primaryPaired.isActive = true
        } else {
            secondaryBtn.isHidden = true
            primaryPaired.isActive = false
            primaryCenterX.isActive = true
        }
    }

    func showCountdown() {
        if Preferences.shared.fullscreenOverlay && overlayWindows.isEmpty {
            showOverlays()
        }

        let quoteList = (breakType == .long) ? Quotes.longBreak : Quotes.countdown
        heading.stringValue = Quotes.random(quoteList)
        heading.textColor = Drac.purple

        body.isHidden = true
        detail.isHidden = true
        countdownLbl.isHidden = false
        countdownSub.isHidden = false
        progressBar.isHidden = false

        primaryBtn.isHidden = true
        secondaryBtn.isHidden = true
        dismissBtn.isHidden = false

        updateCountdown()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 {
                self.secondsLeft = 0
                self.timer?.invalidate()
                self.timer = nil
                self.showComplete()
            } else {
                self.updateCountdown()
            }
        }
    }

    private func updateCountdown() {
        if secondsLeft >= 60 {
            let minutes = secondsLeft / 60
            let seconds = secondsLeft % 60
            countdownLbl.stringValue = String(format: "%d:%02d", minutes, seconds)
            countdownSub.stringValue = "remaining"
        } else {
            countdownLbl.stringValue = "\(secondsLeft)"
            countdownSub.stringValue = "seconds remaining"
        }

        let total = CGFloat(totalDuration > 0 ? totalDuration : 1)
        progressBar.progress = CGFloat(secondsLeft) / total
    }

    func showComplete() {
        SoundManager.shared.playCompleteSound()

        timer?.invalidate()
        timer = nil

        heading.stringValue = "Break complete!"
        heading.textColor = Drac.green

        body.stringValue = Quotes.random(Quotes.complete)
        detail.stringValue = "You may return to your screen."

        body.isHidden = false
        detail.isHidden = false
        countdownLbl.isHidden = true
        countdownSub.isHidden = true
        progressBar.isHidden = true

        primaryBtn.setLabel("Thanks, Count!")
        primaryBtn.isHidden = false
        primaryPaired.isActive = false
        primaryCenterX.isActive = true
        secondaryBtn.isHidden = true
        dismissBtn.isHidden = true

        let delay = Preferences.shared.autoQuitDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) { [weak self] in
            self?.finishWithResult(.completed)
        }
    }

    // MARK: - Button Actions

    @objc private func primaryTapped() {
        if primaryBtn.title == "Thanks, Count!" {
            finishWithResult(.completed)
        } else {
            showCountdown()
        }
    }

    @objc private func snoozeTapped() {
        finishWithResult(.snoozed)
    }

    @objc private func dismissTapped() {
        finishWithResult(.skipped)
    }

    // MARK: - Finish

    func finishWithResult(_ result: BreakResult) {
        guard !hasReportedResult else { return }
        hasReportedResult = true

        timer?.invalidate()
        timer = nil

        for ow in overlayWindows {
            ow.orderOut(nil)
        }
        overlayWindows.removeAll()

        window.orderOut(nil)

        delegate?.breakDidFinish(type: breakType, result: result)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if !hasReportedResult {
            finishWithResult(.skipped)
        }
    }

    // MARK: - Multi-monitor Overlays

    private func showOverlays() {
        guard Preferences.shared.fullscreenOverlay else { return }

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            panel.backgroundColor = Drac.background.withAlphaComponent(0.85)
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
            panel.collectionBehavior = [.canJoinAllSpaces]
            panel.isMovableByWindowBackground = false
            panel.orderFront(nil)
            overlayWindows.append(panel)
        }
    }

    // MARK: - Mascot Animation

    private func startMascotAnimation() {
        mascot.wantsLayer = true

        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = -5
        animation.duration = 2.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        mascot.layer?.add(animation, forKey: "float")
    }
}
