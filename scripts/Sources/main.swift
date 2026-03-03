import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No Dock icon

// Check for --screenshot mode (automated screenshot capture)
let args = ProcessInfo.processInfo.arguments

if args.contains("--screenshot") {
    // Screenshot mode: show break window, cycle through phases, capture screenshots
    let outdir = args.last(where: { $0.hasPrefix("--outdir=") })
        .map { String($0.dropFirst("--outdir=".count)) } ?? "/tmp"

    let controller = BreakWindowController(type: .eye, allowSnooze: true)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        captureWindow(controller.window, to: "\(outdir)/screenshot-prompt.png")

        controller.showCountdown()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            captureWindow(controller.window, to: "\(outdir)/screenshot-countdown.png")

            controller.timer?.invalidate()
            // Manually set complete state for screenshot
            controller.heading.textColor = Drac.green
            controller.heading.stringValue = "Break complete!"
            controller.body.stringValue = "The night rewards those who rest."
            controller.detail.stringValue = "You may return to your screen."
            controller.body.isHidden = false
            controller.detail.isHidden = false
            controller.countdownLbl.isHidden = true
            controller.countdownSub.isHidden = true
            controller.progressBar.isHidden = true
            controller.primaryBtn.setLabel("Thanks, Count!")
            controller.primaryBtn.isHidden = false
            controller.secondaryBtn.isHidden = true
            controller.dismissBtn.isHidden = true
            controller.primaryPaired.isActive = false
            controller.primaryCenterX.isActive = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                captureWindow(controller.window, to: "\(outdir)/screenshot-complete.png")
                NSApp.terminate(nil)
            }
        }
    }
} else {
    // Normal mode: launch as persistent menu bar app
    let delegate = AppDelegate()
    app.delegate = delegate
}

app.run()
