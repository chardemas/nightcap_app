import XCTest
@testable import NightcapCore

final class ChecklistTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func readyContext() -> ChecklistContext {
        ChecklistContext(
            now: now,
            shippedFeatures: [.sobrietyChallenge],
            screenTimeAuthorized: true,
            hasBlockSelection: true,
            homeSaved: true,
            rideAppInstalled: true,
            baselineTaken: true,
            confirmations: [
                .safariCardAutofillOff: now.addingTimeInterval(-60),
                .appStorePasswordAlways: now.addingTimeInterval(-60),
            ]
        )
    }

    func testFreshInstallIsBlockedByEveryRequiredItem() {
        let report = ChecklistReport(ChecklistContext(now: now, shippedFeatures: [.sobrietyChallenge]))
        XCTAssertEqual(Set(report.blockers.map(\.item)), [
            .screenTimeAuthorized, .blockListSelected, .homeAndRideApp, .soberBaseline,
            .safariCardAutofillOff, .appStorePasswordAlways,
        ])
        XCTAssertFalse(report.canStartAfterReconfirm)
        XCTAssertEqual(report.covered, 0)
    }

    func testReadySetupCanStartAndScoresRecommendedAsUncovered() {
        let report = ChecklistReport(readyContext())
        XCTAssertTrue(report.blockers.isEmpty)
        XCTAssertTrue(report.canStartAfterReconfirm)
        XCTAssertEqual(report.covered, 6)
        XCTAssertEqual(report.total, 8) // + wallet, passcode
    }

    func testUnshippedFeaturesDontBlock() {
        var context = readyContext()
        context.shippedFeatures = []
        context.baselineTaken = false
        context.exListCount = 3
        context.usesCheckIn = true
        XCTAssertTrue(ChecklistReport(context).blockers.isEmpty)

        context.shippedFeatures = [.sobrietyChallenge, .exList]
        XCTAssertEqual(Set(ChecklistReport(context).blockers.map(\.item)), [.soberBaseline, .exListProtected])
    }

    func testContactDisguiseAutoSatisfiesExList() {
        var context = readyContext()
        context.shippedFeatures = [.exList]
        context.exListCount = 1
        context.contactDisguiseEnabled = true
        XCTAssertTrue(ChecklistReport(context).blockers.isEmpty)
    }

    func testSelfConfirmationsExpireAfter14Days() {
        var context = readyContext()
        let stale = now.addingTimeInterval(-ChecklistItem.confirmationLifetime - 1)
        context.confirmations[.safariCardAutofillOff] = stale

        let report = ChecklistReport(context)
        XCTAssertEqual(report.blockers.map(\.status), [.expired(confirmedAt: stale)])
        XCTAssertTrue(report.blockedOnlyByExpiry)
        XCTAssertTrue(report.canStartAfterReconfirm)
        XCTAssertEqual(Set(report.reconfirmable), [.safariCardAutofillOff, .appStorePasswordAlways])
    }

    func testNeverConfirmedItemCantBeQuickReconfirmed() {
        var context = readyContext()
        context.confirmations[.appStorePasswordAlways] = nil
        let report = ChecklistReport(context)
        XCTAssertFalse(report.canStartAfterReconfirm)
        XCTAssertFalse(report.reconfirmable.contains(.appStorePasswordAlways))
    }

    func testRequiredItemsSortFirst() {
        let levels = ChecklistReport(readyContext()).entries.map(\.level)
        XCTAssertEqual(levels, levels.sorted { $0 == .required && $1 == .recommended })
        XCTAssertEqual(levels.first, .required)
    }

    func testEverySelfConfirmedItemHasAWalkthrough() {
        for item in ChecklistItem.allCases where item.kind == .selfConfirmed {
            XCTAssertNotNil(item.walkthrough, "\(item) needs a walkthrough")
        }
    }
}

final class SessionTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testDefaultEndIsNextSixAM() {
        XCTAssertEqual(Session.defaultEnd(after: date(6, 22), calendar: calendar), date(7, 6))
        XCTAssertEqual(Session.defaultEnd(after: date(7, 1, 30), calendar: calendar), date(7, 6))
        XCTAssertEqual(Session.defaultEnd(after: date(7, 6), calendar: calendar), date(8, 6))
    }

    func testEndIsClampedToDeviceActivityLimits() {
        let now = date(6, 22)
        XCTAssertEqual(Session.clampedEnd(now.addingTimeInterval(60), now: now), now.addingTimeInterval(Session.minimumDuration))
        XCTAssertEqual(Session.clampedEnd(now.addingTimeInterval(3 * 86_400), now: now), now.addingTimeInterval(Session.maximumDuration))
        XCTAssertEqual(Session.clampedEnd(date(7, 6), now: now), date(7, 6))
    }

    func testIsActive() {
        var session = Session(start: date(6, 22), plannedEnd: date(7, 6), trigger: .manual)
        XCTAssertTrue(session.isActive(at: date(7, 1)))
        XCTAssertFalse(session.isActive(at: date(7, 6)))
        session.actualEnd = date(7, 1)
        XCTAssertFalse(session.isActive(at: date(7, 1)))
    }
}

final class SettingsTests: XCTestCase {
    func testOldSettingsFileDecodesWithDefaults() throws {
        let json = #"{"rideApp":"lyft","strictMode":true}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(NightcapSettings.self, from: json)
        XCTAssertEqual(settings.rideApp, .lyft)
        XCTAssertTrue(settings.strictMode)
        XCTAssertEqual(settings.webPacks, WebDomainPack.defaultOn)
        XCTAssertEqual(settings.foodDelivery, .cap)
    }

    func testConfirmationsRoundTripAsKeyedObject() throws {
        var settings = NightcapSettings()
        settings.selfConfirmations[.walletDoubleClickOff] = Date(timeIntervalSince1970: 0)
        let data = try JSONEncoder().encode(settings)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains(#""walletDoubleClickOff""#))
        XCTAssertEqual(try JSONDecoder().decode(NightcapSettings.self, from: data), settings)
    }

    func testJSONFileUpdateAppends() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = JSONFile<[Int]>("ints.json", in: dir)
        try file.update(default: []) { $0.append(1) }
        try file.update(default: []) { $0.append(2) }
        XCTAssertEqual(file.load(), [1, 2])
    }
}

final class WebAndRideTests: XCTestCase {
    func testDomainPacksDedupeAndRespectFilterLimit() {
        let all = WebDomainPack.domains(for: Set(WebDomainPack.allCases))
        XCTAssertLessThanOrEqual(all.count, WebDomainPack.filterLimit)
        XCTAssertEqual(all.count, Set(all).count)
        XCTAssertEqual(WebDomainPack.domains(for: [.money]), WebDomainPack.money.domains)
    }

    func testRideLinksCarryHomeCoordinates() {
        let home = HomeAddress(label: "Home", latitude: 40.7128, longitude: -74.006)
        let uber = RideApp.uber.rideHomeURL(to: home)?.absoluteString.removingPercentEncoding
        XCTAssertEqual(uber, "uber://?action=setPickup&pickup=my_location&dropoff[latitude]=40.712800&dropoff[longitude]=-74.006000&dropoff[nickname]=Home")
        let lyft = RideApp.lyft.rideHomeURL(to: home)?.absoluteString.removingPercentEncoding
        XCTAssertEqual(lyft, "lyft://ridetype?id=lyft&destination[latitude]=40.712800&destination[longitude]=-74.006000")
    }
}
