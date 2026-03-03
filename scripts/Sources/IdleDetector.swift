import Cocoa
import IOKit

class IdleDetector {
    static let shared = IdleDetector()

    private(set) var isSystemSleeping = false
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    // MARK: - Sleep/wake monitoring

    func startMonitoring() {
        let workspace = NSWorkspace.shared.notificationCenter

        sleepObserver = workspace.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSystemSleeping = true
        }

        wakeObserver = workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSystemSleeping = false
        }
    }

    func stopMonitoring() {
        let workspace = NSWorkspace.shared.notificationCenter
        if let observer = sleepObserver {
            workspace.removeObserver(observer)
            sleepObserver = nil
        }
        if let observer = wakeObserver {
            workspace.removeObserver(observer)
            wakeObserver = nil
        }
    }

    // MARK: - Screen lock

    var isScreenLocked: Bool {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/")
        guard entry != 0 else { return false }
        defer { IOObjectRelease(entry) }

        guard let value = IORegistryEntryCreateCFProperty(
            entry,
            "IOConsoleLocked" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Bool else {
            return false
        }
        return value
    }

    // MARK: - DND / Focus

    var isDNDActive: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let assertionsURL = home
            .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")

        guard let data = try? Data(contentsOf: assertionsURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = root["data"] as? [[String: Any]]
        else { return false }

        for entry in dataArray {
            if let records = entry["storeAssertionRecords"] as? [Any], !records.isEmpty {
                return true
            }
        }
        return false
    }

    // MARK: - Idle detection

    var secondsSinceLastInput: TimeInterval {
        let keyIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .keyDown)
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .mouseMoved)
        let clickIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: .leftMouseDown)
        return min(keyIdle, min(mouseIdle, clickIdle))
    }

    var isUserIdle: Bool {
        guard Preferences.shared.idleDetectionEnabled else { return false }
        return secondsSinceLastInput >= TimeInterval(Preferences.shared.idleThreshold)
    }

    // MARK: - Break deferral

    var shouldDeferBreak: Bool {
        if isSystemSleeping { return true }
        if isScreenLocked { return true }
        if Preferences.shared.dndAware && isDNDActive { return true }
        return false
    }
}
