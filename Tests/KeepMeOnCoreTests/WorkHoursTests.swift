import KeepMeOnCore
import XCTest

final class WorkHoursTests: XCTestCase {
    /// Calendario fisso in UTC: i test non dipendono dal fuso né dall'ora legale.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Settimana di riferimento: lunedì 26 ottobre … domenica 1 novembre 2026.
    private func date(_ weekdayName: String, _ hour: Int, _ minute: Int = 0) -> Date {
        let days = ["lun": (10, 26), "mar": (10, 27), "mer": (10, 28), "gio": (10, 29),
                    "ven": (10, 30), "sab": (10, 31), "dom": (11, 1)]
        let (month, day) = days[weekdayName]!
        let parts = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts)!
    }

    func testReferenceWeekStartsOnMonday() {
        XCTAssertEqual(calendar.component(.weekday, from: date("lun", 12)), 2)
        XCTAssertEqual(calendar.component(.weekday, from: date("dom", 12)), 1)
    }

    func testStandardIsMondayToFridayNineToSix() {
        let hours = WorkHours.standard
        XCTAssertEqual(hours.startMinute, 540)
        XCTAssertEqual(hours.endMinute, 1080)
        XCTAssertEqual(hours.weekdays, [2, 3, 4, 5, 6])
    }

    func testWorkdayInsideHours() {
        XCTAssertTrue(WorkHours.standard.contains(date("mer", 10, 30), calendar: calendar))
    }

    func testStartIsIncludedEndIsExcluded() {
        let hours = WorkHours.standard
        XCTAssertFalse(hours.contains(date("lun", 8, 59), calendar: calendar))
        XCTAssertTrue(hours.contains(date("lun", 9, 0), calendar: calendar))
        XCTAssertTrue(hours.contains(date("lun", 17, 59), calendar: calendar))
        XCTAssertFalse(hours.contains(date("lun", 18, 0), calendar: calendar))
    }

    func testWeekendIsExcluded() {
        XCTAssertFalse(WorkHours.standard.contains(date("sab", 10), calendar: calendar))
        XCTAssertFalse(WorkHours.standard.contains(date("dom", 10), calendar: calendar))
    }

    func testOvernightRangeBelongsToTheDayItStarts() {
        let night = WorkHours(startMinute: 22 * 60, endMinute: 6 * 60, weekdays: [2, 3, 4, 5, 6])
        XCTAssertTrue(night.contains(date("ven", 23), calendar: calendar))
        XCTAssertTrue(night.contains(date("sab", 3), calendar: calendar), "turno iniziato venerdì")
        XCTAssertFalse(night.contains(date("sab", 23), calendar: calendar))
        XCTAssertFalse(night.contains(date("lun", 3), calendar: calendar), "domenica non è selezionata")
        XCTAssertTrue(night.contains(date("mar", 3), calendar: calendar))
        XCTAssertFalse(night.contains(date("mar", 6), calendar: calendar), "la fine è esclusa")
        XCTAssertFalse(night.contains(date("mar", 12), calendar: calendar))
    }

    func testSameStartAndEndCoversWholeDay() {
        let allDay = WorkHours(startMinute: 0, endMinute: 0, weekdays: [7])
        XCTAssertTrue(allDay.contains(date("sab", 0), calendar: calendar))
        XCTAssertTrue(allDay.contains(date("sab", 23, 59), calendar: calendar))
        XCTAssertFalse(allDay.contains(date("ven", 12), calendar: calendar))
    }

    func testNoWeekdaysIsNeverActive() {
        let none = WorkHours(startMinute: 540, endMinute: 1080, weekdays: [])
        for day in ["lun", "mer", "sab", "dom"] {
            XCTAssertFalse(none.contains(date(day, 12), calendar: calendar))
        }
    }

    func testInitClampsInvalidValues() {
        let hours = WorkHours(startMinute: -10, endMinute: 5000, weekdays: [0, 2, 8])
        XCTAssertEqual(hours.startMinute, 0)
        XCTAssertEqual(hours.endMinute, 1439)
        XCTAssertEqual(hours.weekdays, [2])
    }

    func testWeekdayMaskRoundTrip() {
        XCTAssertEqual(WorkHours.standard.weekdayMask, 0b0111110)
        let restored = WorkHours(startMinute: 540, endMinute: 1080, weekdayMask: WorkHours.standard.weekdayMask)
        XCTAssertEqual(restored, .standard)
        let weekend = WorkHours(startMinute: 0, endMinute: 0, weekdays: [1, 7])
        XCTAssertEqual(WorkHours(startMinute: 0, endMinute: 0, weekdayMask: weekend.weekdayMask).weekdays, [1, 7])
    }

    func testSummary() {
        XCTAssertEqual(WorkHours.standard.summary, "lun–ven, 09:00–18:00")
        XCTAssertEqual(WorkHours(startMinute: 8 * 60 + 30, endMinute: 13 * 60, weekdays: [2, 4, 6]).summary,
                       "lun, mer, ven, 08:30–13:00")
        XCTAssertEqual(WorkHours(startMinute: 0, endMinute: 0, weekdays: Set(1...7)).summary,
                       "tutti i giorni, tutto il giorno")
        XCTAssertEqual(WorkHours(startMinute: 22 * 60, endMinute: 6 * 60, weekdays: [7, 1]).summary,
                       "sab, dom, 22:00–06:00")
        XCTAssertEqual(WorkHours(startMinute: 540, endMinute: 1080, weekdays: []).summary,
                       "nessun giorno, 09:00–18:00")
    }
}
