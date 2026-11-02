import KeepMeOnCore
import XCTest

final class LanguageTests: XCTestCase {
    func testDefaultIsEnglish() {
        XCTAssertEqual(Language.standard, .english)
    }

    func testCodesRoundTrip() {
        XCTAssertEqual(Language(rawValue: "en"), .english)
        XCTAssertEqual(Language(rawValue: "it"), .italian)
        XCTAssertNil(Language(rawValue: "fr"))
    }

    func testPick() {
        XCTAssertEqual(Language.english.pick("Settings", "Impostazioni"), "Settings")
        XCTAssertEqual(Language.italian.pick("Settings", "Impostazioni"), "Impostazioni")
    }
}
