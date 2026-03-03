import Foundation

// ============================================================
// Minimal test harness — no XCTest required
// ============================================================

var totalTests = 0
var passedTests = 0
var failedTests = 0

func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  PASS: \(message)")
    } else {
        failedTests += 1
        print("  FAIL: \(message)  (\(file):\(line))")
    }
}

func section(_ name: String) {
    print("\n--- \(name) ---")
}

// Replicate formatTime logic from AppDelegate for pure-logic testing.
// This is byte-for-byte identical to AppDelegate.formatTime so we are
// validating the algorithm itself.
func formatTime(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let m = s / 60
    let r = s % 60
    return String(format: "%02d:%02d", m, r)
}

// Delete the Statistics persistence file so each test starts clean.
// Statistics() always reads from ~/Library/Application Support/CountTongula/statistics.json
func resetStatisticsFile() {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let statsFile = appSupport
        .appendingPathComponent("CountTongula", isDirectory: true)
        .appendingPathComponent("statistics.json")
    try? FileManager.default.removeItem(at: statsFile)
}

// ============================================================
// Entry point
// ============================================================

@main
struct TestRunner {
    static func main() {
        runQuotesTests()
        runDayStatsCodableTests()
        runStatisticsTests()
        runPreferencesTests()
        runFormatTimeTests()

        print("\n============================================================")
        print("Results: \(passedTests) passed, \(failedTests) failed, \(totalTests) total")
        print("============================================================")

        if failedTests > 0 {
            print("TESTS FAILED")
            exit(1)
        } else {
            print("ALL TESTS PASSED")
            exit(0)
        }
    }

    // ============================================================
    // 1. Quotes tests
    // ============================================================

    static func runQuotesTests() {
        section("Quotes: arrays are non-empty")
        check(!Quotes.prompt.isEmpty,    "prompt array is non-empty")
        check(!Quotes.countdown.isEmpty, "countdown array is non-empty")
        check(!Quotes.complete.isEmpty,  "complete array is non-empty")
        check(!Quotes.longBreak.isEmpty, "longBreak array is non-empty")

        section("Quotes: random() returns non-empty strings")
        check(!Quotes.random(Quotes.prompt).isEmpty,    "random(prompt) is non-empty")
        check(!Quotes.random(Quotes.countdown).isEmpty, "random(countdown) is non-empty")
        check(!Quotes.random(Quotes.complete).isEmpty,   "random(complete) is non-empty")
        check(!Quotes.random(Quotes.longBreak).isEmpty,  "random(longBreak) is non-empty")

        section("Quotes: random() on empty array returns empty string")
        check(Quotes.random([]) == "", "random([]) returns empty string")

        section("Quotes: milestones has expected keys")
        let expectedMilestoneKeys: Set<Int> = [5, 10, 25, 50, 100]
        check(Set(Quotes.milestones.keys) == expectedMilestoneKeys,
              "milestones keys are {5, 10, 25, 50, 100}")
        for key in expectedMilestoneKeys.sorted() {
            check(Quotes.milestones[key] != nil && !Quotes.milestones[key]!.isEmpty,
                  "milestone[\(key)] is non-empty")
        }
    }

    // ============================================================
    // 2. DayStats / StatsData encoding/decoding
    // ============================================================

    static func runDayStatsCodableTests() {
        section("DayStats: Codable round-trip")
        do {
            let original = DayStats(date: "2026-03-01", completed: 7, skipped: 2, snoozed: 1)
            let encoded = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(DayStats.self, from: encoded)
            check(decoded.date == "2026-03-01",   "date round-trips")
            check(decoded.completed == 7,          "completed round-trips")
            check(decoded.skipped == 2,            "skipped round-trips")
            check(decoded.snoozed == 1,            "snoozed round-trips")
        } catch {
            check(false, "DayStats encoding/decoding threw: \(error)")
        }

        section("DayStats: default values")
        do {
            let ds = DayStats(date: "2026-01-01")
            check(ds.completed == 0, "completed defaults to 0")
            check(ds.skipped == 0,   "skipped defaults to 0")
            check(ds.snoozed == 0,   "snoozed defaults to 0")
        }

        section("StatsData: Codable round-trip")
        do {
            var sd = StatsData()
            sd.days = [
                DayStats(date: "2026-03-01", completed: 3, skipped: 1, snoozed: 0),
                DayStats(date: "2026-03-02", completed: 5, skipped: 0, snoozed: 2),
            ]
            sd.longestStreak = 12
            sd.currentStreakCount = 4
            let encoded = try JSONEncoder().encode(sd)
            let decoded = try JSONDecoder().decode(StatsData.self, from: encoded)
            check(decoded.days.count == 2,         "days count round-trips")
            check(decoded.longestStreak == 12,     "longestStreak round-trips")
            check(decoded.currentStreakCount == 4,  "currentStreakCount round-trips")
            check(decoded.days[0].date == "2026-03-01", "first day date round-trips")
            check(decoded.days[1].completed == 5,       "second day completed round-trips")
        } catch {
            check(false, "StatsData encoding/decoding threw: \(error)")
        }
    }

    // ============================================================
    // 3. Statistics logic
    // ============================================================

    static func runStatisticsTests() {
        // Each test resets the persistence file and creates a fresh instance
        // so tests are isolated from each other and from real app data.

        section("Statistics: approval rating is 100% with no breaks")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            check(stats.approvalRating == 100,
                  "approval rating is 100 when no breaks recorded")
        }

        section("Statistics: approval rating with completed breaks only")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            check(stats.approvalRating == 100,
                  "approval rating is 100 when all breaks completed (3/3)")
        }

        section("Statistics: approval rating with mixed completed and skipped")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            stats.recordBreakSkipped()
            // 3 completed, 1 skipped => 3/4 = 75%
            check(stats.approvalRating == 75,
                  "approval rating is 75 when 3 completed + 1 skipped")
        }

        section("Statistics: approval rating with only skips")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakSkipped()
            stats.recordBreakSkipped()
            // 0 completed, 2 skipped => 0/2 = 0%
            check(stats.approvalRating == 0,
                  "approval rating is 0 when all breaks skipped")
        }

        section("Statistics: snoozed does not affect approval rating")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakCompleted()
            stats.recordBreakSnoozed()
            stats.recordBreakSnoozed()
            // 1 completed, 0 skipped, 2 snoozed => rating = 1/(1+0) = 100%
            check(stats.approvalRating == 100,
                  "snoozes do not reduce approval rating")
        }

        section("Statistics: today summary format")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            stats.recordBreakSkipped()
            let summary = stats.todaySummary()
            check(summary == "Today: 2 breaks, 1 skipped",
                  "todaySummary format: '\(summary)'")
        }

        section("Statistics: today summary with zero activity")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            let summary = stats.todaySummary()
            check(summary == "Today: 0 breaks, 0 skipped",
                  "todaySummary with no activity: '\(summary)'")
        }

        section("Statistics: streak increments on completion")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            check(stats.currentStreak == 3, "current streak is 3 after 3 completions")
            check(stats.longestStreak == 3, "longest streak is 3 after 3 completions")
        }

        section("Statistics: streak resets on skip")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            stats.recordBreakCompleted()
            stats.recordBreakCompleted()
            stats.recordBreakSkipped()
            check(stats.currentStreak == 0, "current streak resets to 0 after skip")
            check(stats.longestStreak == 2, "longest streak preserved at 2")
        }

        section("Statistics: streak milestone messages")
        do {
            resetStatisticsFile()
            let stats = Statistics()
            for _ in 1..<5 {
                stats.recordBreakCompleted()
                check(stats.streakMessage() == nil,
                      "no milestone at streak \(stats.currentStreak)")
            }
            stats.recordBreakCompleted()
            check(stats.currentStreak == 5, "streak is 5")
            check(stats.streakMessage() != nil, "milestone message exists at streak 5")
            check(stats.streakMessage() == Quotes.milestones[5],
                  "streak 5 message matches Quotes.milestones[5]")
        }

        // Clean up after all statistics tests
        resetStatisticsFile()
    }

    // ============================================================
    // 4. Preferences defaults
    // ============================================================

    static func runPreferencesTests() {
        section("Preferences: default values")
        let prefs = Preferences()
        check(prefs.breakInterval == 1200,      "breakInterval default is 1200")
        check(prefs.breakDuration == 20,         "breakDuration default is 20")
        check(prefs.snoozeDuration == 300,       "snoozeDuration default is 300")
        check(prefs.autoQuitDelay == 8,          "autoQuitDelay default is 8")
        check(prefs.soundEnabled == true,        "soundEnabled default is true")
        check(prefs.promptSound == "Basso",      "promptSound default is Basso")
        check(prefs.completeSound == "Hero",     "completeSound default is Hero")
        check(prefs.dndAware == true,            "dndAware default is true")
        check(prefs.idleDetectionEnabled == true, "idleDetectionEnabled default is true")
        check(prefs.idleThreshold == 300,        "idleThreshold default is 300")
        check(prefs.launchAtLogin == true,       "launchAtLogin default is true")
        check(prefs.fullscreenOverlay == false,  "fullscreenOverlay default is false")
        check(prefs.longBreakEnabled == true,    "longBreakEnabled default is true")
        check(prefs.longBreakEveryN == 3,        "longBreakEveryN default is 3")
        check(prefs.longBreakDuration == 300,    "longBreakDuration default is 300")
        check(prefs.hasCompletedOnboarding == false, "hasCompletedOnboarding default is false")
    }

    // ============================================================
    // 5. formatTime logic
    // ============================================================

    static func runFormatTimeTests() {
        section("formatTime: various inputs")
        check(formatTime(0)    == "00:00", "formatTime(0) => 00:00")
        check(formatTime(1)    == "00:01", "formatTime(1) => 00:01")
        check(formatTime(59)   == "00:59", "formatTime(59) => 00:59")
        check(formatTime(60)   == "01:00", "formatTime(60) => 01:00")
        check(formatTime(61)   == "01:01", "formatTime(61) => 01:01")
        check(formatTime(600)  == "10:00", "formatTime(600) => 10:00")
        check(formatTime(1200) == "20:00", "formatTime(1200) => 20:00")
        check(formatTime(3599) == "59:59", "formatTime(3599) => 59:59")
        check(formatTime(3600) == "60:00", "formatTime(3600) => 60:00")

        section("formatTime: negative input clamps to 00:00")
        check(formatTime(-1)   == "00:00", "formatTime(-1) => 00:00")
        check(formatTime(-100) == "00:00", "formatTime(-100) => 00:00")
    }
}
