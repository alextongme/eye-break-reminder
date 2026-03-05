import Foundation

struct GitHubRelease {
    let tagName: String
    let version: String
    let body: String
    let htmlURL: URL
}

class UpdateChecker {
    static let shared = UpdateChecker()

    private let apiURL = URL(string: "https://api.github.com/repos/alextongme/count-tongulas-eye-break/releases/latest")!
    private let checkInterval: TimeInterval = 6 * 60 * 60  // 6 hours
    private var timer: Timer?

    var onUpdateAvailable: ((GitHubRelease, String) -> Void)?
    var onUpToDate: (() -> Void)?

    private init() {}

    // MARK: - Public API

    /// Called on launch — respects timer, preferences, and skip version.
    func checkIfNeeded() {
        guard Preferences.shared.autoUpdateEnabled else { return }

        let now = Date().timeIntervalSinceReferenceDate
        let last = Preferences.shared.lastUpdateCheck
        if now - last >= checkInterval {
            check(manual: false)
        }

        startTimer()
    }

    /// Called from "Check for Updates..." menu item — always checks, ignores timer/skip.
    func checkNow() {
        check(manual: true)
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            guard Preferences.shared.autoUpdateEnabled else { return }
            self?.check(manual: false)
        }
    }

    // MARK: - Network

    private func check(manual: Bool) {
        var request = URLRequest(url: apiURL)
        request.setValue("CountTongulasEyeBreak", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleResponse(data: data, response: response, error: error, manual: manual)
            }
        }
        task.resume()
    }

    private func handleResponse(data: Data?, response: URLResponse?, error: Error?, manual: Bool) {
        if let error = error {
            NSLog("[UpdateChecker] Network error: %@", error.localizedDescription)
            return
        }

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
            NSLog("[UpdateChecker] Rate limited (HTTP %d)", httpResponse.statusCode)
            return
        }

        guard let data = data else {
            NSLog("[UpdateChecker] No data in response")
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let htmlURLString = json["html_url"] as? String,
              let htmlURL = URL(string: htmlURLString) else {
            NSLog("[UpdateChecker] Failed to parse release JSON")
            return
        }

        let body = json["body"] as? String ?? ""
        let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        Preferences.shared.lastUpdateCheck = Date().timeIntervalSinceReferenceDate

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? appVersion

        guard isVersion(remoteVersion, newerThan: currentVersion) else {
            if manual {
                onUpToDate?()
            }
            return
        }

        // Skip check (automatic only)
        if !manual && Preferences.shared.skippedVersion == remoteVersion {
            return
        }

        // A newer version exists — if a previously skipped version is older than this one, clear it
        if !Preferences.shared.skippedVersion.isEmpty &&
            isVersion(remoteVersion, newerThan: Preferences.shared.skippedVersion) {
            Preferences.shared.skippedVersion = ""
        }

        let release = GitHubRelease(tagName: tagName, version: remoteVersion, body: body, htmlURL: htmlURL)
        onUpdateAvailable?(release, currentVersion)
    }

    // MARK: - Semantic Version Comparison

    /// Returns true if `a` is strictly newer than `b` using semantic versioning.
    func isVersion(_ a: String, newerThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}
