import Foundation

/// Schedule configuration supporting time windows, days of week, and automated actions.
public struct ScheduleConfig: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var startHour: Int
    public var startMinute: Int
    public var stopHour: Int
    public var stopMinute: Int
    public var daysOfWeek: Set<Int> // 1...7 (Sunday = 1, Saturday = 7)
    public var scheduledSpeedLimit: Int64 // Bytes/sec (0 = unlimited / unchanged)
    public var stopWhenFinished: Bool

    public init(
        isEnabled: Bool = false,
        startHour: Int = 2,
        startMinute: Int = 0,
        stopHour: Int = 6,
        stopMinute: Int = 0,
        daysOfWeek: Set<Int> = [1, 2, 3, 4, 5, 6, 7],
        scheduledSpeedLimit: Int64 = 0,
        stopWhenFinished: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.startHour = startHour
        self.startMinute = startMinute
        self.stopHour = stopHour
        self.stopMinute = stopMinute
        self.daysOfWeek = daysOfWeek
        self.scheduledSpeedLimit = scheduledSpeedLimit
        self.stopWhenFinished = stopWhenFinished
    }

    /// Determines whether a given hour/minute falls within the scheduled window.
    public static func isTimeInWindow(
        currentHour: Int,
        currentMinute: Int,
        startHour: Int,
        startMinute: Int,
        stopHour: Int,
        stopMinute: Int
    ) -> Bool {
        let currentMins = currentHour * 60 + currentMinute
        let startMins = startHour * 60 + startMinute
        let stopMins = stopHour * 60 + stopMinute

        if startMins == stopMins {
            return true
        } else if startMins < stopMins {
            return currentMins >= startMins && currentMins < stopMins
        } else {
            // Overnight window spanning past midnight
            return currentMins >= startMins || currentMins < stopMins
        }
    }

    /// Evaluates if active at given date.
    public func isActive(at date: Date = Date(), calendar: Calendar = Calendar.current) -> Bool {
        guard isEnabled else { return false }

        let weekday = calendar.component(.weekday, from: date)
        guard daysOfWeek.contains(weekday) else { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        return Self.isTimeInWindow(
            currentHour: hour,
            currentMinute: minute,
            startHour: startHour,
            startMinute: startMinute,
            stopHour: stopHour,
            stopMinute: stopMinute
        )
    }
}

/// Automated scheduler service evaluating time windows and driving queue state.
@MainActor
public final class QueueTimeScheduler: ObservableObject {
    @Published public var config: ScheduleConfig {
        didSet {
            saveConfig()
        }
    }

    @Published public private(set) var isInActiveWindow: Bool = false
    private weak var scheduler: QueueScheduler?
    private var timer: Timer?

    public init(scheduler: QueueScheduler? = nil) {
        self.scheduler = scheduler
        if let data = UserDefaults.standard.data(forKey: "QueueTimeSchedulerConfig"),
           let saved = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = ScheduleConfig()
        }

        startTimer()
    }

    public func attach(scheduler: QueueScheduler) {
        self.scheduler = scheduler
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluate()
            }
        }
    }

    /// Evaluates current time and updates queue accordingly.
    public func evaluate(currentDate: Date = Date(), calendar: Calendar = Calendar.current) {
        guard config.isEnabled, let sched = scheduler else {
            isInActiveWindow = false
            return
        }

        let currentlyActive = config.isActive(at: currentDate, calendar: calendar)
        let stateChanged = (currentlyActive != isInActiveWindow)
        self.isInActiveWindow = currentlyActive

        if stateChanged {
            if currentlyActive {
                // Scheduled window opened -> Start/Resume queue
                if config.scheduledSpeedLimit > 0 {
                    sched.setSpeedLimit(bytesPerSecond: config.scheduledSpeedLimit)
                }
                sched.resumeAll()
            } else {
                // Scheduled window closed -> Pause queue
                sched.pauseAll()
            }
        }
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "QueueTimeSchedulerConfig")
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
