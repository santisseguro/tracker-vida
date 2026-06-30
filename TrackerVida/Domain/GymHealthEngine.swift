import Foundation

enum GymHealthTrackStatus: String, Codable, Equatable {
    case ahead
    case onTrack
    case behind
}

struct GymHealthProgress: Equatable {
    var currentWeightKg: Double?
    var sevenDayAverageWeightKg: Double?
    var weightRemainingKg: Double?
    var dailyCalorieTarget: Int
    var weeklyCalorieTarget: Int
    var weeklyCaloriesConsumed: Int
    var dailyCalorieDelta: Int?
    var weeklyCalorieDelta: Int
    var estimatedWeightImpactKg: Double
    var estimatedTargetDate: Date?
    var completedWorkouts: Int
    var targetWorkouts: Int
    var trackStatus: GymHealthTrackStatus
}

struct GymHealthEngine {
    var calendar: Calendar
    var caloriesPerKilogram: Double
    var calorieDeltaTolerance: Int
    var targetDateToleranceDays: Int

    init(
        calendar: Calendar = .current,
        caloriesPerKilogram: Double = 7_700,
        calorieDeltaTolerance: Int = 350,
        targetDateToleranceDays: Int = 3
    ) {
        self.calendar = calendar
        self.caloriesPerKilogram = caloriesPerKilogram
        self.calorieDeltaTolerance = calorieDeltaTolerance
        self.targetDateToleranceDays = targetDateToleranceDays
    }

    func progress(
        weightGoal: WeightGoal,
        weightLogs: [WeightLog],
        dailyHealthLogs: [DailyHealthLog],
        referenceDate: Date
    ) -> GymHealthProgress {
        let currentWeight = currentWeight(from: weightLogs)
        let averageWeight = sevenDayMovingAverageWeight(from: weightLogs, referenceDate: referenceDate)
        let recentLogs = rollingSevenDayHealthLogs(from: dailyHealthLogs, referenceDate: referenceDate)
        let todayLog = dailyHealthLogs.first { isSameDay($0.date, referenceDate) }
        let dailyTarget = dailyCalorieTarget(for: referenceDate, log: todayLog, goal: weightGoal)
        let weeklyTarget = weeklyCalorieTarget(goal: weightGoal, dailyHealthLogs: dailyHealthLogs, referenceDate: referenceDate)
        let weeklyConsumed = weeklyCaloriesConsumed(from: dailyHealthLogs, referenceDate: referenceDate)
        let dailyDelta = todayLog?.totalCalories.map { $0 - dailyTarget }
        let weeklyDelta = weeklyConsumed - weeklyTarget
        let weightImpact = estimatedWeightImpactKg(fromCalorieDelta: weeklyDelta)
        let targetDate = estimatedTargetDate(
            currentWeightKg: currentWeight,
            targetWeightKg: weightGoal.targetWeightKg,
            weeklyCalorieDelta: weeklyDelta,
            referenceDate: referenceDate
        )
        let completedWorkouts = recentLogs.gymAttendanceCount
        let targetWorkouts = max(0, weightGoal.targetWorkoutsPerWeek)
        let status = trackStatus(
            currentWeightKg: currentWeight,
            targetWeightKg: weightGoal.targetWeightKg,
            targetDate: weightGoal.targetDate,
            estimatedTargetDate: targetDate,
            weeklyCalorieDelta: weeklyDelta,
            completedWorkouts: completedWorkouts,
            targetWorkouts: targetWorkouts
        )

        return GymHealthProgress(
            currentWeightKg: currentWeight,
            sevenDayAverageWeightKg: averageWeight,
            weightRemainingKg: weightRemainingKg(currentWeightKg: currentWeight, targetWeightKg: weightGoal.targetWeightKg),
            dailyCalorieTarget: dailyTarget,
            weeklyCalorieTarget: weeklyTarget,
            weeklyCaloriesConsumed: weeklyConsumed,
            dailyCalorieDelta: dailyDelta,
            weeklyCalorieDelta: weeklyDelta,
            estimatedWeightImpactKg: weightImpact,
            estimatedTargetDate: targetDate,
            completedWorkouts: completedWorkouts,
            targetWorkouts: targetWorkouts,
            trackStatus: status
        )
    }

    func currentWeight(from weightLogs: [WeightLog]) -> Double? {
        weightLogs.latest?.weightKg
    }

    func sevenDayMovingAverageWeight(from weightLogs: [WeightLog], referenceDate: Date) -> Double? {
        let values = weightLogs
            .filter { isInRollingSevenDayWindow($0.date, referenceDate: referenceDate) }
            .map(\.weightKg)

        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func weightRemainingKg(currentWeightKg: Double?, targetWeightKg: Double) -> Double? {
        guard let currentWeightKg else { return nil }
        return abs(currentWeightKg - targetWeightKg)
    }

    func dailyCalorieTarget(for date: Date, log: DailyHealthLog?, goal: WeightGoal) -> Int {
        isGymDay(date, log: log, goal: goal) ? goal.gymDayCalorieTarget : goal.restDayCalorieTarget
    }

    func weeklyCalorieTarget(goal: WeightGoal, dailyHealthLogs: [DailyHealthLog], referenceDate: Date) -> Int {
        rollingSevenDayDates(endingOn: referenceDate).reduce(0) { total, date in
            let log = dailyHealthLogs.first { isSameDay($0.date, date) }
            return total + dailyCalorieTarget(for: date, log: log, goal: goal)
        }
    }

    func weeklyCaloriesConsumed(from dailyHealthLogs: [DailyHealthLog], referenceDate: Date) -> Int {
        rollingSevenDayHealthLogs(from: dailyHealthLogs, referenceDate: referenceDate).totalCalories
    }

    func dailyCalorieDelta(consumed: Int?, target: Int) -> Int? {
        consumed.map { $0 - target }
    }

    func weeklyCalorieDelta(consumed: Int, target: Int) -> Int {
        consumed - target
    }

    func estimatedWeightImpactKg(fromCalorieDelta calorieDelta: Int) -> Double {
        Double(calorieDelta) / caloriesPerKilogram
    }

    func estimatedTargetDate(
        currentWeightKg: Double?,
        targetWeightKg: Double,
        weeklyCalorieDelta: Int,
        referenceDate: Date
    ) -> Date? {
        guard let currentWeightKg else { return nil }

        let remainingDelta = targetWeightKg - currentWeightKg
        guard abs(remainingDelta) > 0.05 else { return referenceDate }

        let estimatedWeeklyWeightChange = -Double(weeklyCalorieDelta) / caloriesPerKilogram
        guard estimatedWeeklyWeightChange != 0 else { return nil }
        guard remainingDelta.sign == estimatedWeeklyWeightChange.sign else { return nil }

        let weeksToGoal = abs(remainingDelta / estimatedWeeklyWeightChange)
        let daysToGoal = Int(ceil(weeksToGoal * 7))
        return calendar.date(byAdding: .day, value: daysToGoal, to: referenceDate)
    }

    func gymWeeklyProgress(from dailyHealthLogs: [DailyHealthLog], goal: WeightGoal, referenceDate: Date) -> (completed: Int, target: Int) {
        (
            completed: rollingSevenDayHealthLogs(from: dailyHealthLogs, referenceDate: referenceDate).gymAttendanceCount,
            target: max(0, goal.targetWorkoutsPerWeek)
        )
    }

    func trackStatus(
        currentWeightKg: Double?,
        targetWeightKg: Double,
        targetDate: Date?,
        estimatedTargetDate: Date?,
        weeklyCalorieDelta: Int,
        completedWorkouts: Int,
        targetWorkouts: Int
    ) -> GymHealthTrackStatus {
        if let targetDate, let estimatedTargetDate {
            let targetDay = calendar.startOfDay(for: targetDate)
            let estimatedDay = calendar.startOfDay(for: estimatedTargetDate)
            let dayDifference = calendar.dateComponents([.day], from: targetDay, to: estimatedDay).day ?? 0

            if dayDifference > targetDateToleranceDays {
                return .behind
            }

            if dayDifference < -targetDateToleranceDays {
                return .ahead
            }

            return .onTrack
        }

        guard let currentWeightKg else {
            return completedWorkouts >= targetWorkouts ? .onTrack : .behind
        }

        let wantsWeightLoss = currentWeightKg > targetWeightKg
        let calorieStatus = calorieTrackStatus(weeklyCalorieDelta: weeklyCalorieDelta, wantsWeightLoss: wantsWeightLoss)

        if completedWorkouts < targetWorkouts {
            return calorieStatus == .ahead ? .onTrack : .behind
        }

        if completedWorkouts > targetWorkouts, calorieStatus == .onTrack {
            return .ahead
        }

        return calorieStatus
    }

    func rollingSevenDayHealthLogs(from dailyHealthLogs: [DailyHealthLog], referenceDate: Date) -> [DailyHealthLog] {
        dailyHealthLogs.filter { isInRollingSevenDayWindow($0.date, referenceDate: referenceDate) }
    }

    private func calorieTrackStatus(weeklyCalorieDelta: Int, wantsWeightLoss: Bool) -> GymHealthTrackStatus {
        if abs(weeklyCalorieDelta) <= calorieDeltaTolerance {
            return .onTrack
        }

        if wantsWeightLoss {
            return weeklyCalorieDelta < 0 ? .ahead : .behind
        }

        return weeklyCalorieDelta > 0 ? .ahead : .behind
    }

    private func rollingSevenDayDates(endingOn referenceDate: Date) -> [Date] {
        let endDay = calendar.startOfDay(for: referenceDate)

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: endDay)
        }
        .reversed()
    }

    private func isInRollingSevenDayWindow(_ date: Date, referenceDate: Date) -> Bool {
        let endDay = calendar.startOfDay(for: referenceDate)
        let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        let day = calendar.startOfDay(for: date)

        return day >= startDay && day <= endDay
    }

    private func isGymDay(_ date: Date, log: DailyHealthLog?, goal: WeightGoal) -> Bool {
        if let log {
            return log.gymAttended
        }

        let weekday = calendar.component(.weekday, from: date)
        return goal.idealGymWeekdays.contains(weekday)
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
