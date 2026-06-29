import Combine
import Foundation

struct DashboardViewState {
    var latestWeight: WeightLog?
    var todayHealth: DailyHealthLog?
    var weeklyGymCount: Int
    var dailyOrderPlan: AIGeneratedDailyOrderPlan
    var activeCriticalTasks: [AcademicTask]
    var upcomingDeadlines: [AcademicTask]
    var accountBalances: [SimpleListItem]
    var weightGoal: WeightGoal
}

struct GymHealthViewState {
    var latestWeight: WeightLog?
    var todayHealth: DailyHealthLog?
    var weeklyCalories: Int
    var gymAttendance: Int
    var averageSleepHours: Double
    var weightGoal: WeightGoal
    var dailyOrderPlan: AIGeneratedDailyOrderPlan
}

struct UniversityViewState {
    var activeCriticalTasks: [AcademicTask]
    var upcomingDeadlines: [AcademicTask]
    var waitingResponses: [SimpleListItem]
    var timeline: [SimpleListItem]
}

struct MoneyViewState {
    var activeAccounts: [MoneyAccount]
    var accountBalances: [SimpleListItem]
    var transactions: [MoneyTransaction]
}

struct DailyOrdersViewState {
    var plan: AIGeneratedDailyOrderPlan
    var totalItems: Int
    var completedItems: Int
}

@MainActor
final class AppStore: ObservableObject {
    let currentDate: Date

    @Published var weightGoal: WeightGoal
    @Published var weightLogs: [WeightLog]
    @Published var dailyHealthLogs: [DailyHealthLog]
    @Published var dailyOrderPlan: AIGeneratedDailyOrderPlan
    @Published var criticalTasks: [AcademicTask]
    @Published var upcomingDeadlines: [AcademicTask]
    @Published var waitingResponses: [SimpleListItem]
    @Published var timeline: [SimpleListItem]
    @Published var moneyAccounts: [MoneyAccount]
    @Published var accountBalances: [SimpleListItem]
    @Published var moneyTransactions: [MoneyTransaction]
    @Published var settingsSections: [SimpleListItem]

    private let calendar: Calendar

    init(
        currentDate: Date = MockData.today,
        calendar: Calendar = MockData.calendar,
        weightGoal: WeightGoal = MockData.weightGoal,
        weightLogs: [WeightLog] = MockData.weightLogs,
        dailyHealthLogs: [DailyHealthLog] = MockData.dailyHealthLogs,
        dailyOrderPlan: AIGeneratedDailyOrderPlan = MockData.dailyOrderPlan,
        criticalTasks: [AcademicTask] = MockData.criticalTasks,
        upcomingDeadlines: [AcademicTask] = MockData.upcomingDeadlines,
        waitingResponses: [SimpleListItem] = MockData.waitingResponses,
        timeline: [SimpleListItem] = MockData.timeline,
        moneyAccounts: [MoneyAccount] = MockData.moneyAccounts,
        accountBalances: [SimpleListItem] = MockData.accountBalances,
        moneyTransactions: [MoneyTransaction] = MockData.moneyTransactions,
        settingsSections: [SimpleListItem] = MockData.settingsSections
    ) {
        self.currentDate = currentDate
        self.calendar = calendar
        self.weightGoal = weightGoal
        self.weightLogs = weightLogs
        self.dailyHealthLogs = dailyHealthLogs
        self.dailyOrderPlan = dailyOrderPlan
        self.criticalTasks = criticalTasks
        self.upcomingDeadlines = upcomingDeadlines
        self.waitingResponses = waitingResponses
        self.timeline = timeline
        self.moneyAccounts = moneyAccounts
        self.accountBalances = accountBalances
        self.moneyTransactions = moneyTransactions
        self.settingsSections = settingsSections
    }

    var dashboardState: DashboardViewState {
        DashboardViewState(
            latestWeight: weightLogs.latest,
            todayHealth: dailyHealthLog(on: currentDate),
            weeklyGymCount: dailyHealthLogs.gymAttendanceCount,
            dailyOrderPlan: dailyOrderPlan,
            activeCriticalTasks: activeCriticalTasks,
            upcomingDeadlines: activeUpcomingDeadlines,
            accountBalances: accountBalances,
            weightGoal: weightGoal
        )
    }

    var gymHealthState: GymHealthViewState {
        GymHealthViewState(
            latestWeight: weightLogs.latest,
            todayHealth: dailyHealthLog(on: currentDate),
            weeklyCalories: dailyHealthLogs.totalCalories,
            gymAttendance: dailyHealthLogs.gymAttendanceCount,
            averageSleepHours: dailyHealthLogs.averageSleepHours,
            weightGoal: weightGoal,
            dailyOrderPlan: dailyOrderPlan
        )
    }

    var universityState: UniversityViewState {
        UniversityViewState(
            activeCriticalTasks: activeCriticalTasks,
            upcomingDeadlines: activeUpcomingDeadlines,
            waitingResponses: waitingTaskItems + waitingResponses,
            timeline: timeline
        )
    }

    var moneyState: MoneyViewState {
        MoneyViewState(
            activeAccounts: moneyAccounts.filter { $0.status == .active },
            accountBalances: accountBalances,
            transactions: moneyTransactions
        )
    }

    var dailyOrdersState: DailyOrdersViewState {
        let items = dailyOrderPlan.orders.flatMap(\.checklist)
        let completed = items.filter { $0.status == .done || $0.status == .skipped }.count

        return DailyOrdersViewState(
            plan: dailyOrderPlan,
            totalItems: items.count,
            completedItems: completed
        )
    }

    func weightLog(on date: Date) -> WeightLog? {
        weightLogs.first { isSameDay($0.date, date) }
    }

    func dailyHealthLog(on date: Date) -> DailyHealthLog? {
        dailyHealthLogs.first { isSameDay($0.date, date) }
    }

    func upsertWeightLog(date: Date, weightKg: Double, enteredAt: Date = .now) {
        if let index = weightLogs.firstIndex(where: { isSameDay($0.date, date) }) {
            weightLogs[index].date = date
            weightLogs[index].weightKg = weightKg
            weightLogs[index].source = HealthSourceMetadata(source: .manual)
            weightLogs[index].lateEntry = lateEntryMetadata(for: date, enteredAt: enteredAt)
            weightLogs[index].metadata.updatedAt = enteredAt
        } else {
            weightLogs.append(
                WeightLog(
                    metadata: BaseMetadata(createdAt: enteredAt, updatedAt: enteredAt),
                    date: date,
                    weightKg: weightKg,
                    source: HealthSourceMetadata(source: .manual),
                    lateEntry: lateEntryMetadata(for: date, enteredAt: enteredAt)
                )
            )
        }

        weightLogs.sort { $0.date < $1.date }
    }

    func upsertDailyHealthLog(
        date: Date,
        totalCalories: Int?,
        gymAttended: Bool,
        workoutDurationMinutes: Int?,
        workoutType: WorkoutType?,
        sleepHours: Double?,
        sleepQuality: SleepQuality?,
        enteredAt: Date = .now
    ) {
        if let index = dailyHealthLogs.firstIndex(where: { isSameDay($0.date, date) }) {
            dailyHealthLogs[index].date = date
            dailyHealthLogs[index].totalCalories = totalCalories
            dailyHealthLogs[index].gymAttended = gymAttended
            dailyHealthLogs[index].workoutDurationMinutes = gymAttended ? workoutDurationMinutes : nil
            dailyHealthLogs[index].workoutType = gymAttended ? workoutType : nil
            dailyHealthLogs[index].sleepHours = sleepHours
            dailyHealthLogs[index].sleepQuality = sleepHours == nil ? nil : sleepQuality
            dailyHealthLogs[index].source = HealthSourceMetadata(source: .manual)
            dailyHealthLogs[index].lateEntry = lateEntryMetadata(for: date, enteredAt: enteredAt)
            dailyHealthLogs[index].metadata.updatedAt = enteredAt
        } else {
            dailyHealthLogs.append(
                DailyHealthLog(
                    metadata: BaseMetadata(createdAt: enteredAt, updatedAt: enteredAt),
                    date: date,
                    totalCalories: totalCalories,
                    gymAttended: gymAttended,
                    workoutDurationMinutes: gymAttended ? workoutDurationMinutes : nil,
                    workoutType: gymAttended ? workoutType : nil,
                    sleepHours: sleepHours,
                    sleepQuality: sleepHours == nil ? nil : sleepQuality,
                    source: HealthSourceMetadata(source: .manual),
                    lateEntry: lateEntryMetadata(for: date, enteredAt: enteredAt)
                )
            )
        }

        dailyHealthLogs.sort { $0.date < $1.date }
    }

    func toggleDailyChecklistItem(_ itemID: EntityID) {
        for orderIndex in dailyOrderPlan.orders.indices {
            guard let itemIndex = dailyOrderPlan.orders[orderIndex].checklist.firstIndex(where: { $0.id == itemID }) else {
                continue
            }

            let currentStatus = dailyOrderPlan.orders[orderIndex].checklist[itemIndex].status
            dailyOrderPlan.orders[orderIndex].checklist[itemIndex].status = currentStatus == .done ? .pending : .done
            dailyOrderPlan.orders[orderIndex].metadata.updatedAt = .now
            dailyOrderPlan.metadata.updatedAt = .now
            return
        }
    }

    func universityTask(id taskID: EntityID) -> AcademicTask? {
        allUniversityTasks.first { $0.id == taskID }
    }

    @discardableResult
    func addUniversityTask(
        title: String,
        category: AcademicTaskCategory,
        status: AcademicTaskStatus,
        priority: AcademicTaskPriority,
        dueDate: Date?,
        notes: String?,
        waitingSince: Date?,
        createdAt: Date = .now
    ) -> AcademicTask {
        let task = normalizedAcademicTask(
            AcademicTask(
                metadata: BaseMetadata(createdAt: createdAt, updatedAt: createdAt),
                courseID: nil,
                title: title,
                category: category,
                status: status,
                priority: priority,
                dueDate: dueDate,
                waitingSince: waitingSince,
                notes: notes,
                links: []
            ),
            timestamp: createdAt
        )

        insertUniversityTask(task)
        return task
    }

    func updateUniversityTask(_ updatedTask: AcademicTask, updatedAt: Date = .now) {
        var task = normalizedAcademicTask(updatedTask, timestamp: updatedAt)
        task.metadata.updatedAt = updatedAt

        removeUniversityTask(task.id)
        insertUniversityTask(task)
    }

    func updateAcademicTaskStatus(_ taskID: EntityID, status: AcademicTaskStatus, waitingSince: Date? = nil, updatedAt: Date = .now) {
        guard var task = universityTask(id: taskID) else { return }

        task.status = status
        task.waitingSince = waitingSince
        updateUniversityTask(task, updatedAt: updatedAt)
    }

    func updateAcademicTaskPriority(_ taskID: EntityID, priority: AcademicTaskPriority, updatedAt: Date = .now) {
        guard var task = universityTask(id: taskID) else { return }

        task.priority = priority
        updateUniversityTask(task, updatedAt: updatedAt)
    }

    func markAcademicTaskCompleted(_ taskID: EntityID) {
        updateAcademicTaskStatus(taskID, status: .completed)
    }

    private var allUniversityTasks: [AcademicTask] {
        criticalTasks + upcomingDeadlines
    }

    private var activeCriticalTasks: [AcademicTask] {
        sortedUniversityTasks(
            allUniversityTasks.filter { !$0.isComplete && $0.priority == .critical }
        )
    }

    private var activeUpcomingDeadlines: [AcademicTask] {
        sortedUniversityTasks(
            allUniversityTasks.filter { !$0.isComplete && $0.priority != .critical }
        )
    }

    private var waitingTaskItems: [SimpleListItem] {
        sortedUniversityTasks(
            allUniversityTasks.filter { !$0.isComplete && $0.status == .waitingResponse }
        )
        .map { task in
            SimpleListItem(
                title: task.title,
                detail: task.notes ?? task.category.rawValue,
                value: task.waitingSince?.formatted(date: .abbreviated, time: .omitted) ?? "Open"
            )
        }
    }

    private func normalizedAcademicTask(_ task: AcademicTask, timestamp: Date) -> AcademicTask {
        var task = task

        if task.status == .waitingResponse {
            task.waitingSince = task.waitingSince ?? timestamp
        } else {
            task.waitingSince = nil
        }

        if task.status == .completed {
            task.completedAt = task.completedAt ?? timestamp
        } else {
            task.completedAt = nil
        }

        task.notes = normalizedOptionalText(task.notes)
        return task
    }

    private func insertUniversityTask(_ task: AcademicTask) {
        if task.priority == .critical {
            criticalTasks.append(task)
            criticalTasks = sortedUniversityTasks(criticalTasks)
        } else {
            upcomingDeadlines.append(task)
            upcomingDeadlines = sortedUniversityTasks(upcomingDeadlines)
        }
    }

    private func removeUniversityTask(_ taskID: EntityID) {
        criticalTasks.removeAll { $0.id == taskID }
        upcomingDeadlines.removeAll { $0.id == taskID }
    }

    private func sortedUniversityTasks(_ tasks: [AcademicTask]) -> [AcademicTask] {
        tasks.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.metadata.createdAt < rhs.metadata.createdAt
            }
        }
    }

    private func normalizedOptionalText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func lateEntryMetadata(for date: Date, enteredAt: Date) -> LateEntryMetadata? {
        let entryDay = calendar.startOfDay(for: date)
        let currentDay = calendar.startOfDay(for: currentDate)

        guard entryDay < currentDay else { return nil }

        return LateEntryMetadata(
            isLateEntry: true,
            originalEntryDate: date,
            enteredAt: enteredAt
        )
    }
}
