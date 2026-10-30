import KeepMeOnCore
import XCTest

final class LunchBreakTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Mercoledì 28 ottobre 2026.
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: hour, minute: minute))!
    }

    func testStandardIsOneToTwo() {
        XCTAssertEqual(LunchBreak.standard.startMinute, 13 * 60)
        XCTAssertEqual(LunchBreak.standard.endMinute, 14 * 60)
        XCTAssertEqual(LunchBreak.standard.summary, "13:00–14:00")
    }

    func testStartIsIncludedEndIsExcluded() {
        let lunch = LunchBreak.standard
        XCTAssertFalse(lunch.contains(at(12, 59), calendar: calendar))
        XCTAssertTrue(lunch.contains(at(13, 0), calendar: calendar))
        XCTAssertTrue(lunch.contains(at(13, 59), calendar: calendar))
        XCTAssertFalse(lunch.contains(at(14, 0), calendar: calendar))
    }

    func testSameStartAndEndIsEmpty() {
        let empty = LunchBreak(startMinute: 13 * 60, endMinute: 13 * 60)
        XCTAssertFalse(empty.contains(at(13, 0), calendar: calendar))
        XCTAssertFalse(empty.contains(at(9), calendar: calendar))
    }

    func testOvernightBreak() {
        let night = LunchBreak(startMinute: 23 * 60, endMinute: 1 * 60)
        XCTAssertTrue(night.contains(at(23, 30), calendar: calendar))
        XCTAssertTrue(night.contains(at(0, 30), calendar: calendar))
        XCTAssertFalse(night.contains(at(1, 0), calendar: calendar))
        XCTAssertFalse(night.contains(at(12), calendar: calendar))
    }

    func testInitClampsInvalidValues() {
        let lunch = LunchBreak(startMinute: -5, endMinute: 9999)
        XCTAssertEqual(lunch.startMinute, 0)
        XCTAssertEqual(lunch.endMinute, 1439)
    }
}
