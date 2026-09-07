import SwiftUI
import MacDownloaderCore

public struct SchedulerSheet: View {
    @ObservedObject public var timeScheduler: QueueTimeScheduler
    @Environment(\.dismiss) private var dismiss

    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var stopHour: Int
    @State private var stopMinute: Int
    @State private var selectedDays: Set<Int>
    @State private var isEnabled: Bool

    public init(timeScheduler: QueueTimeScheduler) {
        self.timeScheduler = timeScheduler
        self._isEnabled = State(initialValue: timeScheduler.config.isEnabled)
        self._startHour = State(initialValue: timeScheduler.config.startHour)
        self._startMinute = State(initialValue: timeScheduler.config.startMinute)
        self._stopHour = State(initialValue: timeScheduler.config.stopHour)
        self._stopMinute = State(initialValue: timeScheduler.config.stopMinute)
        self._selectedDays = State(initialValue: timeScheduler.config.daysOfWeek)
    }

    private let dayNames = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Title Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Queue Schedule & Automation")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }

            Toggle("Enable Time-Based Queue Scheduling", isOn: $isEnabled)
                .font(.headline)

            if isEnabled {
                VStack(alignment: .leading, spacing: 14) {
                    // Time Window Box
                    GroupBox("Download Time Window") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Start Downloads at:")
                                Spacer()
                                Picker("Hour", selection: $startHour) {
                                    ForEach(0..<24) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .frame(width: 70)
                                Text(":")
                                Picker("Minute", selection: $startMinute) {
                                    ForEach(0..<60) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .frame(width: 70)
                            }

                            HStack {
                                Text("Stop / Pause Downloads at:")
                                Spacer()
                                Picker("Hour", selection: $stopHour) {
                                    ForEach(0..<24) { h in
                                        Text(String(format: "%02d", h)).tag(h)
                                    }
                                }
                                .frame(width: 70)
                                Text(":")
                                Picker("Minute", selection: $stopMinute) {
                                    ForEach(0..<60) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .frame(width: 70)
                            }
                        }
                        .padding(6)
                    }

                    // Active Days
                    GroupBox("Active Days of Week") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                ForEach(dayNames, id: \.0) { day in
                                    let isSelected = selectedDays.contains(day.0)
                                    Button(action: {
                                        if isSelected {
                                            if selectedDays.count > 1 { selectedDays.remove(day.0) }
                                        } else {
                                            selectedDays.insert(day.0)
                                        }
                                    }) {
                                        Text(day.1)
                                            .font(.caption)
                                            .fontWeight(isSelected ? .bold : .regular)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            HStack(spacing: 10) {
                                Button("Every Day") {
                                    selectedDays = [1, 2, 3, 4, 5, 6, 7]
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.caption)

                                Button("Weekdays Only") {
                                    selectedDays = [2, 3, 4, 5, 6]
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.caption)

                                Button("Weekends Only") {
                                    selectedDays = [1, 7]
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .font(.caption)
                            }
                        }
                        .padding(6)
                    }

                    // Current Window Status
                    HStack {
                        Circle()
                            .fill(timeScheduler.isInActiveWindow ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(timeScheduler.isInActiveWindow ? "Currently inside active window — Queue running" : "Currently outside window — Queue paused")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Actions
            HStack {
                Spacer()
                Button("Save & Apply") {
                    applySchedule()
                    dismiss()
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480, height: 420)
    }

    private func applySchedule() {
        timeScheduler.config.isEnabled = isEnabled
        timeScheduler.config.startHour = startHour
        timeScheduler.config.startMinute = startMinute
        timeScheduler.config.stopHour = stopHour
        timeScheduler.config.stopMinute = stopMinute
        timeScheduler.config.daysOfWeek = selectedDays
        timeScheduler.evaluate()
    }
}
