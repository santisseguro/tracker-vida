import Foundation

struct GymHealthDailyOrderGenerator {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func generate(
        progress: GymHealthProgress,
        date: Date,
        todayHealth: DailyHealthLog?,
        hasWeightLogToday: Bool,
        existingPlan: AIGeneratedDailyOrderPlan?
    ) -> AIGeneratedDailyOrderPlan {
        let existingStatuses = existingPlan?.orders.flatMap(\.checklist).reduce(into: [EntityID: DailyOrderStatus]()) { result, item in
            result[item.id] = item.status
        } ?? [:]

        let items = checklistItems(
            progress: progress,
            todayHealth: todayHealth,
            hasWeightLogToday: hasWeightLogToday,
            existingStatuses: existingStatuses
        )
        let title = title(for: progress.trackStatus)
        let metadata = BaseMetadata(
            id: deterministicUUID("gym-health-order-plan-\(dayKey(for: date))"),
            createdAt: existingPlan?.metadata.createdAt ?? date,
            updatedAt: date
        )
        let orderMetadata = BaseMetadata(
            id: deterministicUUID("gym-health-order-\(dayKey(for: date))"),
            createdAt: existingPlan?.orders.first?.metadata.createdAt ?? date,
            updatedAt: date
        )

        return AIGeneratedDailyOrderPlan(
            metadata: metadata,
            date: date,
            source: .aiGenerated,
            generatedAt: date,
            promptVersion: "local-rule-v1",
            summary: explanation(for: progress),
            orders: [
                DailyOrder(
                    metadata: orderMetadata,
                    title: title,
                    area: .gymHealth,
                    status: orderStatus(for: items),
                    priority: priority(for: progress.trackStatus),
                    checklist: items,
                    sourceEntityIDs: []
                )
            ]
        )
    }

    private func checklistItems(
        progress: GymHealthProgress,
        todayHealth: DailyHealthLog?,
        hasWeightLogToday: Bool,
        existingStatuses: [EntityID: DailyOrderStatus]
    ) -> [DailyChecklistItem] {
        var items: [DailyChecklistItem] = []

        if !hasWeightLogToday {
            items.append(item(
                key: "weight-log",
                title: "Log today's weight. No guessing.",
                kind: .task,
                priority: .high,
                rationale: "Current weight drives every health calculation.",
                existingStatuses: existingStatuses
            ))
        }

        if let dailyDelta = progress.dailyCalorieDelta, dailyDelta > 0 {
            items.append(item(
                key: "calorie-correction",
                title: "Correct calories by \(dailyDelta). Stop the spillover today.",
                kind: .task,
                priority: .high,
                rationale: "Today's intake is above the calculated target.",
                existingStatuses: existingStatuses
            ))
        }

        let remainingWorkouts = max(0, progress.targetWorkouts - progress.completedWorkouts)
        if remainingWorkouts > 0, todayHealth?.gymAttended != true {
            items.append(item(
                key: "gym-at-risk",
                title: "Train today. \(remainingWorkouts) workout\(remainingWorkouts == 1 ? "" : "s") still missing.",
                kind: .task,
                priority: .high,
                rationale: "Weekly gym target is not complete.",
                existingStatuses: existingStatuses
            ))
        }

        if let sleepHours = todayHealth?.sleepHours, sleepHours < 6.5 {
            items.append(item(
                key: "sleep-low",
                title: "Protect sleep tonight. Minimum 7 hours.",
                kind: .reminder,
                priority: .medium,
                rationale: "Logged sleep is below the recovery floor.",
                existingStatuses: existingStatuses
            ))
        } else if todayHealth?.sleepQuality == .bad {
            items.append(item(
                key: "sleep-bad",
                title: "Fix sleep tonight. No late drift.",
                kind: .reminder,
                priority: .medium,
                rationale: "Logged sleep quality is bad.",
                existingStatuses: existingStatuses
            ))
        }

        items.append(item(
            key: "track-status-\(progress.trackStatus.rawValue)",
            title: statusChecklistTitle(for: progress),
            kind: .review,
            priority: priority(for: progress.trackStatus),
            rationale: "Generated from current health progress.",
            existingStatuses: existingStatuses
        ))

        return items
    }

    private func item(
        key: String,
        title: String,
        kind: DailyOrderItemKind,
        priority: PriorityLevel,
        rationale: String,
        existingStatuses: [EntityID: DailyOrderStatus]
    ) -> DailyChecklistItem {
        let id = deterministicUUID("gym-health-daily-order-\(key)")

        return DailyChecklistItem(
            id: id,
            title: title,
            kind: kind,
            area: .gymHealth,
            status: existingStatuses[id] ?? .pending,
            priority: priority,
            rationale: rationale
        )
    }

    private func title(for status: GymHealthTrackStatus) -> String {
        switch status {
        case .behind:
            return "Correct the plan today."
        case .onTrack:
            return "Hold the plan today."
        case .ahead:
            return "Keep the lead today."
        }
    }

    private func explanation(for progress: GymHealthProgress) -> String {
        let workoutText = "\(progress.completedWorkouts)/\(progress.targetWorkouts) workouts"
        let weeklyDelta = progress.weeklyCalorieDelta

        switch progress.trackStatus {
        case .behind:
            return "You are behind. Fix the gap today: \(workoutText), \(weeklyDelta) kcal weekly delta. No drift."
        case .onTrack:
            return "You are on track. Maintain the plan: \(workoutText), \(weeklyDelta) kcal weekly delta."
        case .ahead:
            return "You are ahead. Do not get sloppy: \(workoutText), \(weeklyDelta) kcal weekly delta."
        }
    }

    private func statusChecklistTitle(for progress: GymHealthProgress) -> String {
        switch progress.trackStatus {
        case .behind:
            if let date = progress.estimatedTargetDate {
                return "Close the gap. Estimated target date: \(date.formatted(date: .abbreviated, time: .omitted))."
            }
            return "Close the gap. Follow the numbers today."
        case .onTrack:
            return "Maintain calories and gym rhythm. Do not add noise."
        case .ahead:
            return "Keep the rhythm. Do not spend the lead."
        }
    }

    private func orderStatus(for items: [DailyChecklistItem]) -> DailyOrderStatus {
        guard !items.isEmpty else { return .pending }

        let completedCount = items.filter { $0.status == .done || $0.status == .skipped }.count
        if completedCount == items.count {
            return .done
        }

        return completedCount > 0 ? .inProgress : .pending
    }

    private func priority(for status: GymHealthTrackStatus) -> PriorityLevel {
        switch status {
        case .behind:
            return .urgent
        case .onTrack:
            return .medium
        case .ahead:
            return .high
        }
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private func deterministicUUID(_ string: String) -> UUID {
        var hash: UInt64 = 0xcbf29ce484222325

        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }

        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8((hash >> UInt64(index * 8)) & 0xff)
            bytes[index + 8] = UInt8((~hash >> UInt64(index * 8)) & 0xff)
        }

        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
