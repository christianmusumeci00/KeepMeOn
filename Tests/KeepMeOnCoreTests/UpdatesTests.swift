import KeepMeOnCore
import XCTest

final class UpdatesTests: XCTestCase {
    /// Estratto di una risposta reale di GitHub (campi usati dall'app più qualche altro).
    private let sampleJSON = """
        {
          "tag_name": "v1.2.0",
          "name": "KeepMeOn 1.2.0",
          "html_url": "https://github.com/christianmusumeci00/KeepMeOn/releases/tag/v1.2.0",
          "draft": false,
          "prerelease": false,
          "assets": [
            {"name": "KeepMeOn.dmg", "size": 876543,
             "browser_download_url": "https://github.com/christianmusumeci00/KeepMeOn/releases/download/v1.2.0/KeepMeOn.dmg"},
            {"name": "KeepMeOn-Setup.exe", "size": 2262094,
             "browser_download_url": "https://github.com/christianmusumeci00/KeepMeOn/releases/download/v1.2.0/KeepMeOn-Setup.exe"}
          ]
        }
        """

    func testParsesVersions() {
        XCTAssertEqual(AppVersion("1.2.0")?.components, [1, 2, 0])
        XCTAssertEqual(AppVersion("v1.10")?.components, [1, 10])
        XCTAssertEqual(AppVersion(" V2.0.1-beta ")?.components, [2, 0, 1])
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("windows-v1.0.0-prova1"))
        XCTAssertNil(AppVersion("1..2"))
        XCTAssertEqual(AppVersion("1.2.0")?.description, "1.2.0")
    }

    func testComparesVersions() {
        XCTAssertLessThan(AppVersion("1.1.0")!, AppVersion("1.2.0")!)
        XCTAssertLessThan(AppVersion("1.9.0")!, AppVersion("1.10.0")!)
        XCTAssertLessThan(AppVersion("1.2")!, AppVersion("1.2.1")!)
        XCTAssertEqual(AppVersion("1.2")!, AppVersion("v1.2.0")!)
        XCTAssertGreaterThan(AppVersion("2.0.0")!, AppVersion("1.99.99")!)
    }

    func testDecodesRelease() throws {
        let release = try ReleaseInfo.decode(Data(sampleJSON.utf8))
        XCTAssertEqual(release.tagName, "v1.2.0")
        XCTAssertEqual(release.version, AppVersion("1.2.0"))
        XCTAssertEqual(release.pageURL.absoluteString, "https://github.com/christianmusumeci00/KeepMeOn/releases/tag/v1.2.0")
        XCTAssertEqual(release.asset(named: "KeepMeOn.dmg")?.size, 876543)
        XCTAssertEqual(release.asset(named: "KeepMeOn-Setup.exe")?.downloadURL.lastPathComponent, "KeepMeOn-Setup.exe")
        XCTAssertNil(release.asset(named: "altro.zip"))
    }

    func testAvailableUpdateOnlyWhenNewerAndFilePresent() throws {
        let release = try ReleaseInfo.decode(Data(sampleJSON.utf8))
        XCTAssertNotNil(UpdatePolicy.availableUpdate(in: release, current: AppVersion("1.1.0")!, assetName: "KeepMeOn.dmg"))
        XCTAssertNil(UpdatePolicy.availableUpdate(in: release, current: AppVersion("1.2.0")!, assetName: "KeepMeOn.dmg"))
        XCTAssertNil(UpdatePolicy.availableUpdate(in: release, current: AppVersion("1.3.0")!, assetName: "KeepMeOn.dmg"))
        XCTAssertNil(UpdatePolicy.availableUpdate(in: release, current: AppVersion("1.1.0")!, assetName: "altro.zip"))
    }

    func testSkippedVersionIsOfferedOnlyByHandOrWhenNewer() {
        let v130 = AppVersion("1.3.0")!
        XCTAssertTrue(UpdatePolicy.shouldOffer(v130, skipped: nil, userInitiated: false))
        XCTAssertFalse(UpdatePolicy.shouldOffer(v130, skipped: v130, userInitiated: false))
        XCTAssertTrue(UpdatePolicy.shouldOffer(v130, skipped: v130, userInitiated: true))
        XCTAssertTrue(UpdatePolicy.shouldOffer(AppVersion("1.3.1")!, skipped: v130, userInitiated: false))
        XCTAssertFalse(UpdatePolicy.shouldOffer(AppVersion("1.2.9")!, skipped: v130, userInitiated: false))
    }

    func testCheckIsDueOncePerDay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(UpdatePolicy.isCheckDue(lastCheck: nil, now: now))
        XCTAssertFalse(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
        // Un orologio spostato indietro non deve bloccare i controlli.
        XCTAssertTrue(UpdatePolicy.isCheckDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }
}
