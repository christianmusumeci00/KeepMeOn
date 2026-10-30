import KeepMeOnCore
import XCTest

final class SchedulerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Mercoledì 28 ottobre 2026.
    private func wednesday(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: hour))!
    }

    private func state(
        enabled: Bool = true,
        asleep: Bool = false,
        locked: Bool = false,
        workHoursOnly: Bool = false,
        at date: Date
    ) -> KeeperState {
        Scheduler.state(isEnabled: enabled, isAsleep: asleep, isScreenLocked: locked,
                        workHoursOnly: workHoursOnly, workHours: .standard, now: date, calendar: calendar)
    }

    func testDisabledIsOffWhateverElseHappens() {
        XCTAssertEqual(state(enabled: false, at: wednesday(10)), .off)
        XCTAssertEqual(state(enabled: false, asleep: true, locked: true, workHoursOnly: true, at: wednesday(22)), .off)
    }

    func testActiveWithoutWorkHoursAtAnyTime() {
        XCTAssertEqual(state(at: wednesday(10)), .active)
        XCTAssertEqual(state(at: wednesday(3)), .active)
    }

    func testWorkHoursOnly() {
        XCTAssertEqual(state(workHoursOnly: true, at: wednesday(10)), .active)
        XCTAssertEqual(state(workHoursOnly: true, at: wednesday(20)), .pausedOutsideHours)
    }

    func testLockAndSleepPause() {
        XCTAssertEqual(state(locked: true, at: wednesday(10)), .pausedScreenLocked)
        XCTAssertEqual(state(asleep: true, at: wednesday(10)), .pausedAsleep)
    }

    func testPausePriority() {
        // Stop prima del blocco, blocco prima della fascia oraria.
        XCTAssertEqual(state(asleep: true, locked: true, workHoursOnly: true, at: wednesday(20)), .pausedAsleep)
        XCTAssertEqual(state(locked: true, workHoursOnly: true, at: wednesday(20)), .pausedScreenLocked)
    }

    func testLunchBreakPauses() {
        let lunch = LunchBreak.standard
        func state(at hour: Int, workHoursOnly: Bool = false, lunch: LunchBreak?) -> KeeperState {
            Scheduler.state(isEnabled: true, isAsleep: false, isScreenLocked: false, workHoursOnly: workHoursOnly,
                            workHours: .standard, lunchBreak: lunch, now: wednesday(hour), calendar: calendar)
        }
        XCTAssertEqual(state(at: 13, lunch: lunch), .pausedLunch)
        XCTAssertEqual(state(at: 12, lunch: lunch), .active)
        XCTAssertEqual(state(at: 13, lunch: nil), .active, "pausa pranzo disattivata")
        XCTAssertEqual(state(at: 13, workHoursOnly: true, lunch: lunch), .pausedLunch)
    }

    func testOutsideHoursWinsOverLunch() {
        let lateLunch = LunchBreak(startMinute: 20 * 60, endMinute: 21 * 60)
        let state = Scheduler.state(isEnabled: true, isAsleep: false, isScreenLocked: false, workHoursOnly: true,
                                    workHours: .standard, lunchBreak: lateLunch, now: wednesday(20), calendar: calendar)
        XCTAssertEqual(state, .pausedOutsideHours)
    }

    func testLockWinsOverLunch() {
        let state = Scheduler.state(isEnabled: true, isAsleep: false, isScreenLocked: true, workHoursOnly: false,
                                    workHours: .standard, lunchBreak: .standard, now: wednesday(13), calendar: calendar)
        XCTAssertEqual(state, .pausedScreenLocked)
    }

    func testDeclaresOnlyPastThreshold() {
        let threshold = Scheduler.defaultIdleThreshold
        XCTAssertFalse(Scheduler.shouldDeclareActivity(idleSeconds: 5, threshold: threshold))
        XCTAssertFalse(Scheduler.shouldDeclareActivity(idleSeconds: 119.9, threshold: threshold))
        XCTAssertTrue(Scheduler.shouldDeclareActivity(idleSeconds: 120, threshold: threshold))
        XCTAssertTrue(Scheduler.shouldDeclareActivity(idleSeconds: 600, threshold: threshold))
    }

    func testThresholdStaysAtBaseForShortIntervals() {
        for interval in [30.0, 60, 120] {
            XCTAssertEqual(Scheduler.idleThreshold(base: 120, interval: interval), 120, "intervallo \(interval)")
        }
    }

    func testThresholdDropsForLongInterval() {
        // 300 − 15 di margine − 240 − 24 di tolleranza.
        XCTAssertEqual(Scheduler.idleThreshold(base: 120, interval: 240), 21)
    }

    func testWorstCaseIdleStaysBelowTeamsLimit() {
        for interval in [30.0, 60, 120, 240] {
            let threshold = Scheduler.idleThreshold(base: 120, interval: interval)
            let worstCase = threshold + interval + Scheduler.timerTolerance(forInterval: interval)
            XCTAssertLessThan(worstCase, Scheduler.teamsAwayAfter, "intervallo \(interval)")
        }
    }

    func testThresholdNeverNegative() {
        XCTAssertEqual(Scheduler.idleThreshold(base: 120, interval: 600), 0)
    }

    func testTimerToleranceIsTenPercent() {
        XCTAssertEqual(Scheduler.timerTolerance(forInterval: 60), 6)
        XCTAssertEqual(Scheduler.timerTolerance(forInterval: 240), 24)
    }
}
