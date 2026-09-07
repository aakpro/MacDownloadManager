import XCTest
@testable import MacDownloaderCore

final class QueueTimeSchedulerTests: XCTestCase {

    func testStandardWindowContainment() {
        // Window: 10:00 to 14:30
        let inWindow = ScheduleConfig.isTimeInWindow(
            currentHour: 11, currentMinute: 15,
            startHour: 10, startMinute: 0,
            stopHour: 14, stopMinute: 30
        )
        XCTAssertTrue(inWindow)

        // Exact start boundary
        let atStart = ScheduleConfig.isTimeInWindow(
            currentHour: 10, currentMinute: 0,
            startHour: 10, startMinute: 0,
            stopHour: 14, stopMinute: 30
        )
        XCTAssertTrue(atStart)

        // Exact stop boundary (exclusive)
        let atStop = ScheduleConfig.isTimeInWindow(
            currentHour: 14, currentMinute: 30,
            startHour: 10, startMinute: 0,
            stopHour: 14, stopMinute: 30
        )
        XCTAssertFalse(atStop)

        // Before start
        let before = ScheduleConfig.isTimeInWindow(
            currentHour: 9, currentMinute: 59,
            startHour: 10, startMinute: 0,
            stopHour: 14, stopMinute: 30
        )
        XCTAssertFalse(before)

        // After stop
        let after = ScheduleConfig.isTimeInWindow(
            currentHour: 15, currentMinute: 0,
            startHour: 10, startMinute: 0,
            stopHour: 14, stopMinute: 30
        )
        XCTAssertFalse(after)
    }

    func testOvernightWindowContainment() {
        // Overnight Window: 23:00 to 06:00
        let lateNight = ScheduleConfig.isTimeInWindow(
            currentHour: 23, currentMinute: 30,
            startHour: 23, startMinute: 0,
            stopHour: 6, stopMinute: 0
        )
        XCTAssertTrue(lateNight)

        let earlyMorning = ScheduleConfig.isTimeInWindow(
            currentHour: 3, currentMinute: 15,
            startHour: 23, startMinute: 0,
            stopHour: 6, stopMinute: 0
        )
        XCTAssertTrue(earlyMorning)

        // Noon is outside
        let midday = ScheduleConfig.isTimeInWindow(
            currentHour: 12, currentMinute: 0,
            startHour: 23, startMinute: 0,
            stopHour: 6, stopMinute: 0
        )
        XCTAssertFalse(midday)
    }

    func testDaysOfWeekFilter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Create date for Monday (weekday = 2) at 03:00
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 9
        comps.day = 7 // 2026-09-07 was a Monday
        comps.hour = 3
        comps.minute = 0
        let mondayDate = calendar.date(from: comps)!

        // Config only enabled on weekends: Saturday (7), Sunday (1)
        let weekendConfig = ScheduleConfig(
            isEnabled: true,
            startHour: 2, startMinute: 0,
            stopHour: 5, stopMinute: 0,
            daysOfWeek: [1, 7]
        )
        XCTAssertFalse(weekendConfig.isActive(at: mondayDate, calendar: calendar))

        // Config enabled on weekdays
        let weekdayConfig = ScheduleConfig(
            isEnabled: true,
            startHour: 2, startMinute: 0,
            stopHour: 5, stopMinute: 0,
            daysOfWeek: [2, 3, 4, 5, 6]
        )
        XCTAssertTrue(weekdayConfig.isActive(at: mondayDate, calendar: calendar))
    }

    func testSchedulerStateTransitions() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("scheduler_test_\(UUID().uuidString)")
        let persistence = PersistenceManager(customStorageDirectory: tempDir)
        let queue = await QueueScheduler(persistenceManager: persistence)

        let timeScheduler = await QueueTimeScheduler(scheduler: queue)

        await MainActor.run {
            timeScheduler.config.isEnabled = true
            timeScheduler.config.startHour = 2
            timeScheduler.config.startMinute = 0
            timeScheduler.config.stopHour = 5
            timeScheduler.config.stopMinute = 0
            timeScheduler.config.daysOfWeek = [1, 2, 3, 4, 5, 6, 7]

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            var comps = DateComponents(year: 2026, month: 9, day: 7, hour: 3, minute: 0)
            let insideDate = cal.date(from: comps)!

            timeScheduler.evaluate(currentDate: insideDate, calendar: cal)
            XCTAssertTrue(timeScheduler.isInActiveWindow)

            // Move to outside date
            comps.hour = 8
            let outsideDate = cal.date(from: comps)!
            timeScheduler.evaluate(currentDate: outsideDate, calendar: cal)
            XCTAssertFalse(timeScheduler.isInActiveWindow)
        }
    }
}
