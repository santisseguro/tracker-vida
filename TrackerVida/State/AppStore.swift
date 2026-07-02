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
    var moneyTotals: MoneyTotals
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
    var progress: GymHealthProgress
}

struct UniversityViewState {
    var activeCriticalTasks: [AcademicTask]
    var upcomingDeadlines: [AcademicTask]
    var waitingResponses: [SimpleListItem]
    var timeline: [SimpleListItem]
    var classes: [UniversityClass]
    var todayClasses: [UniversityScheduledClass]
    var upcomingClassesThisWeek: [UniversityScheduledClass]
}

struct MoneyViewState {
    var activeAccounts: [MoneyAccount]
    var accountBalances: [SimpleListItem]
    var transactions: [MoneyTransaction]
    var totals: MoneyTotals
}

struct DailyOrdersViewState {
    var plan: AIGeneratedDailyOrderPlan
    var totalItems: Int
    var completedItems: Int
}

struct MoneyTotals {
    var arsMinorUnits: Int
    var usdtMinorUnits: Int
    var mockUSDTToARSRate: Int

    var arsDisplay: String {
        "$\(arsMinorUnits.formatted())"
    }

    var usdtDisplay: String {
        "\(usdtMinorUnits.formatted())"
    }

    var arsEquivalentDisplay: String {
        "$\(arsEquivalentMinorUnits.formatted()) ARS"
    }

    var usdtLabeledDisplay: String {
        "\(usdtMinorUnits.formatted()) USDT"
    }

    var dashboardDisplay: String {
        "$\(abbreviatedARSEquivalent)"
    }

    var arsEquivalentMinorUnits: Int {
        arsMinorUnits + (usdtMinorUnits * mockUSDTToARSRate)
    }

    private var abbreviatedARSEquivalent: String {
        let absolute = abs(arsEquivalentMinorUnits)

        if absolute >= 1_000 {
            return "\(arsEquivalentMinorUnits / 1_000)K"
        }

        return arsEquivalentMinorUnits.formatted()
    }
}

@MainActor
final class AppStore: ObservableObject {
    let currentDate: Date

    @Published private(set) var persistenceError: AppStatePersistenceError?
    @Published var weightGoal: WeightGoal
    @Published var weightLogs: [WeightLog]
    @Published var dailyHealthLogs: [DailyHealthLog]
    @Published var dailyOrderPlan: AIGeneratedDailyOrderPlan
    @Published var criticalTasks: [AcademicTask]
    @Published var upcomingDeadlines: [AcademicTask]
    @Published var waitingResponses: [SimpleListItem]
    @Published var timeline: [SimpleListItem]
    @Published var universityClasses: [UniversityClass]
    @Published var universityScheduleSessions: [UniversityScheduleSession]
    @Published var moneyAccounts: [MoneyAccount]
    @Published var moneyTransactions: [MoneyTransaction]
    @Published var settingsSections: [SimpleListItem]
    @Published private(set) var capturedAICommands: [CapturedAICommand] = []

    private let calendar: Calendar
    private let mockUSDTToARSRate: Int
    private let persistence: AppStatePersisting?
    private let gymHealthEngine: GymHealthEngine
    private let dailyOrderGenerator: GymHealthDailyOrderGenerator

    init(
        currentDate: Date = MockData.today,
        calendar: Calendar = MockData.calendar,
        persistence: AppStatePersisting? = nil,
        weightGoal: WeightGoal = MockData.weightGoal,
        weightLogs: [WeightLog] = MockData.weightLogs,
        dailyHealthLogs: [DailyHealthLog] = MockData.dailyHealthLogs,
        dailyOrderPlan: AIGeneratedDailyOrderPlan = MockData.dailyOrderPlan,
        criticalTasks: [AcademicTask] = MockData.criticalTasks,
        upcomingDeadlines: [AcademicTask] = MockData.upcomingDeadlines,
        waitingResponses: [SimpleListItem] = MockData.waitingResponses,
        timeline: [SimpleListItem] = MockData.timeline,
        universityClasses: [UniversityClass] = MockData.universityClasses,
        universityScheduleSessions: [UniversityScheduleSession] = MockData.universityScheduleSessions,
        moneyAccounts: [MoneyAccount] = MockData.moneyAccounts,
        moneyTransactions: [MoneyTransaction] = MockData.moneyTransactions,
        settingsSections: [SimpleListItem] = MockData.settingsSections,
        mockUSDTToARSRate: Int = 1_000
    ) {
        self.currentDate = currentDate
        self.calendar = calendar
        self.mockUSDTToARSRate = mockUSDTToARSRate
        self.persistence = persistence
        self.gymHealthEngine = GymHealthEngine(calendar: calendar)
        self.dailyOrderGenerator = GymHealthDailyOrderGenerator(calendar: calendar)

        let restoredState: PersistedAppState?
        do {
            restoredState = try persistence?.load()
        } catch let error as AppStatePersistenceError {
            restoredState = nil
            persistenceError = error
        } catch {
            restoredState = nil
            persistenceError = .loadFailed(error.localizedDescription)
        }

        if let restoredState {
            self.weightGoal = restoredState.weightGoal
            self.weightLogs = restoredState.weightLogs
            self.dailyHealthLogs = restoredState.dailyHealthLogs
            self.dailyOrderPlan = restoredState.dailyOrderPlan
            self.criticalTasks = restoredState.criticalTasks
            self.upcomingDeadlines = restoredState.upcomingDeadlines
            self.waitingResponses = restoredState.waitingResponses
            self.timeline = restoredState.timeline
            self.universityClasses = restoredState.universityClasses
            self.universityScheduleSessions = restoredState.universityScheduleSessions
            self.moneyAccounts = restoredState.moneyAccounts
            self.moneyTransactions = restoredState.moneyTransactions
            self.settingsSections = settingsSections
            refreshDailyOrder(save: false)
            return
        }

        self.weightGoal = weightGoal
        self.weightLogs = weightLogs
        self.dailyHealthLogs = dailyHealthLogs
        self.dailyOrderPlan = dailyOrderPlan
        self.criticalTasks = criticalTasks
        self.upcomingDeadlines = upcomingDeadlines
        self.waitingResponses = waitingResponses
        self.timeline = timeline
        self.universityClasses = universityClasses
        self.universityScheduleSessions = universityScheduleSessions
        self.moneyAccounts = moneyAccounts
        self.moneyTransactions = moneyTransactions
        self.settingsSections = settingsSections
        refreshDailyOrder(save: false)
    }

    var dashboardState: DashboardViewState {
        DashboardViewState(
            latestWeight: weightLogs.latest,
            todayHealth: dailyHealthLog(on: currentDate),
            weeklyGymCount: gymHealthProgress.completedWorkouts,
            dailyOrderPlan: dailyOrderPlan,
            activeCriticalTasks: activeCriticalTasks,
            upcomingDeadlines: activeUpcomingDeadlines,
            accountBalances: moneyAccountBalanceItems,
            moneyTotals: moneyTotals,
            weightGoal: weightGoal
        )
    }

    var gymHealthState: GymHealthViewState {
        let progress = gymHealthProgress

        return GymHealthViewState(
            latestWeight: weightLogs.latest,
            todayHealth: dailyHealthLog(on: currentDate),
            weeklyCalories: progress.weeklyCaloriesConsumed,
            gymAttendance: progress.completedWorkouts,
            averageSleepHours: recentHealthLogs.averageSleepHours,
            weightGoal: weightGoal,
            dailyOrderPlan: dailyOrderPlan,
            progress: progress
        )
    }

    var universityState: UniversityViewState {
        UniversityViewState(
            activeCriticalTasks: activeCriticalTasks,
            upcomingDeadlines: activeUpcomingDeadlines,
            waitingResponses: waitingTaskItems + waitingResponses,
            timeline: timeline,
            classes: activeUniversityClasses,
            todayClasses: todayUniversityClasses,
            upcomingClassesThisWeek: upcomingUniversityClassesThisWeek
        )
    }

    var moneyState: MoneyViewState {
        MoneyViewState(
            activeAccounts: moneyAccounts.filter { $0.status == .active },
            accountBalances: moneyAccountBalanceItems,
            transactions: moneyTransactions,
            totals: moneyTotals
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

    func latestCapturedAICommand(for context: AICommandContext) -> CapturedAICommand? {
        capturedAICommands.first { $0.context == context }
    }

    @discardableResult
    func captureAICommand(_ text: String, context: AICommandContext, createdAt: Date = .now) -> CapturedAICommand? {
        let command = CapturedAICommand(context: context, text: text, createdAt: createdAt)
        guard !command.text.isEmpty else { return nil }

        capturedAICommands.insert(command, at: 0)
        return command
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
        refreshDailyOrder(save: false)
        saveState()
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
        refreshDailyOrder(save: false)
        saveState()
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
            saveState()
            return
        }
    }

    func moneyAccount(id accountID: EntityID) -> MoneyAccount? {
        moneyAccounts.first { $0.id == accountID }
    }

    @discardableResult
    func addMoneyAccount(
        name: String,
        currency: CurrencyCode,
        currentBalance: Int,
        status: MoneyAccountStatus = .active,
        color: MoneyAccountColor = .money,
        createdAt: Date = .now
    ) -> MoneyAccount {
        let account = MoneyAccount(
            metadata: BaseMetadata(createdAt: createdAt, updatedAt: createdAt),
            name: normalizedRequiredText(name, fallback: "Account"),
            currency: currency,
            currentBalance: MoneyAmount(minorUnits: currentBalance, currency: currency),
            kind: currency == .usdt ? .cryptoWallet : .digitalWallet,
            status: status,
            color: color
        )

        moneyAccounts.append(account)
        moneyAccounts = sortedMoneyAccounts(moneyAccounts)
        saveState()
        return account
    }

    func updateMoneyAccount(_ updatedAccount: MoneyAccount, updatedAt: Date = .now) {
        guard let index = moneyAccounts.firstIndex(where: { $0.id == updatedAccount.id }) else { return }

        var account = updatedAccount
        account.metadata.updatedAt = updatedAt
        account.currentBalance.currency = account.currency

        moneyAccounts[index] = account
        moneyAccounts = sortedMoneyAccounts(moneyAccounts)
        saveState()
    }

    @discardableResult
    func addIncomeTransaction(
        title: String,
        amount: Int,
        toAccountID: EntityID,
        category: IncomeCategory,
        date: Date = .now,
        notes: String? = nil
    ) -> MoneyTransaction? {
        guard let accountIndex = moneyAccounts.firstIndex(where: { $0.id == toAccountID }) else { return nil }
        let account = moneyAccounts[accountIndex]
        let transactionAmount = MoneyAmount(minorUnits: abs(amount), currency: account.currency)
        moneyAccounts[accountIndex].currentBalance.minorUnits += transactionAmount.minorUnits

        let transaction = MoneyTransaction(
            metadata: BaseMetadata(createdAt: date, updatedAt: date),
            date: date,
            title: normalizedRequiredText(title, fallback: "Income"),
            kind: .income,
            amount: transactionAmount,
            toAccountID: toAccountID,
            category: .income(category),
            notes: normalizedOptionalText(notes)
        )

        moneyTransactions.insert(transaction, at: 0)
        saveState()
        return transaction
    }

    @discardableResult
    func addExpenseTransaction(
        title: String,
        amount: Int,
        fromAccountID: EntityID,
        category: ExpenseCategory,
        date: Date = .now,
        notes: String? = nil
    ) -> MoneyTransaction? {
        guard let accountIndex = moneyAccounts.firstIndex(where: { $0.id == fromAccountID }) else { return nil }
        let account = moneyAccounts[accountIndex]
        let transactionAmount = MoneyAmount(minorUnits: abs(amount), currency: account.currency)
        moneyAccounts[accountIndex].currentBalance.minorUnits -= transactionAmount.minorUnits

        let transaction = MoneyTransaction(
            metadata: BaseMetadata(createdAt: date, updatedAt: date),
            date: date,
            title: normalizedRequiredText(title, fallback: "Expense"),
            kind: .expense,
            amount: transactionAmount,
            fromAccountID: fromAccountID,
            category: .expense(category),
            notes: normalizedOptionalText(notes)
        )

        moneyTransactions.insert(transaction, at: 0)
        saveState()
        return transaction
    }

    @discardableResult
    func addTransferTransaction(
        title: String,
        amount: Int,
        fromAccountID: EntityID,
        toAccountID: EntityID,
        date: Date = .now,
        notes: String? = nil
    ) -> MoneyTransaction? {
        guard fromAccountID != toAccountID,
              let fromIndex = moneyAccounts.firstIndex(where: { $0.id == fromAccountID }),
              let toIndex = moneyAccounts.firstIndex(where: { $0.id == toAccountID })
        else { return nil }

        let sourceAccount = moneyAccounts[fromIndex]
        let destinationAccount = moneyAccounts[toIndex]
        let outgoingAmount = MoneyAmount(minorUnits: abs(amount), currency: sourceAccount.currency)
        let incomingAmount = convertedAmount(outgoingAmount, to: destinationAccount.currency)

        moneyAccounts[fromIndex].currentBalance.minorUnits -= outgoingAmount.minorUnits
        moneyAccounts[toIndex].currentBalance.minorUnits += incomingAmount.minorUnits

        let transaction = MoneyTransaction(
            metadata: BaseMetadata(createdAt: date, updatedAt: date),
            date: date,
            title: normalizedRequiredText(title, fallback: "Transfer"),
            kind: .transfer,
            amount: outgoingAmount,
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            notes: normalizedOptionalText(notes)
        )

        moneyTransactions.insert(transaction, at: 0)
        saveState()
        return transaction
    }

    @discardableResult
    func addBalanceAdjustmentTransaction(
        title: String,
        accountID: EntityID,
        newBalance: Int,
        date: Date = .now,
        notes: String? = nil
    ) -> MoneyTransaction? {
        guard let accountIndex = moneyAccounts.firstIndex(where: { $0.id == accountID }) else { return nil }

        let previousBalance = moneyAccounts[accountIndex].currentBalance
        let updatedBalance = MoneyAmount(minorUnits: newBalance, currency: previousBalance.currency)
        let difference = updatedBalance.minorUnits - previousBalance.minorUnits
        moneyAccounts[accountIndex].currentBalance = updatedBalance

        let transaction = MoneyTransaction(
            metadata: BaseMetadata(createdAt: date, updatedAt: date),
            date: date,
            title: normalizedRequiredText(title, fallback: "Balance adjustment"),
            kind: .balanceAdjustment,
            amount: MoneyAmount(minorUnits: difference, currency: previousBalance.currency),
            fromAccountID: difference < 0 ? accountID : nil,
            toAccountID: difference >= 0 ? accountID : nil,
            balanceBefore: previousBalance,
            balanceAfter: updatedBalance,
            notes: normalizedOptionalText(notes)
        )

        moneyTransactions.insert(transaction, at: 0)
        saveState()
        return transaction
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
        saveState()
        return task
    }

    func updateUniversityTask(_ updatedTask: AcademicTask, updatedAt: Date = .now) {
        var task = normalizedAcademicTask(updatedTask, timestamp: updatedAt)
        task.metadata.updatedAt = updatedAt

        removeUniversityTask(task.id)
        insertUniversityTask(task)
        saveState()
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

    @discardableResult
    func addUniversityClass(
        name: String,
        shortName: String? = nil,
        instructor: String? = nil,
        location: String? = nil,
        color: UniversityClassColor? = .university,
        notes: String? = nil,
        createdAt: Date = .now
    ) -> UniversityClass {
        let universityClass = UniversityClass(
            metadata: BaseMetadata(createdAt: createdAt, updatedAt: createdAt),
            name: normalizedRequiredText(name, fallback: "Class"),
            shortName: normalizedOptionalText(shortName),
            instructor: normalizedOptionalText(instructor),
            location: normalizedOptionalText(location),
            color: color,
            status: .active,
            notes: normalizedOptionalText(notes)
        )

        universityClasses.append(universityClass)
        universityClasses = sortedUniversityClasses(universityClasses)
        saveState()
        return universityClass
    }

    func updateUniversityClass(_ updatedClass: UniversityClass, updatedAt: Date = .now) {
        guard let index = universityClasses.firstIndex(where: { $0.id == updatedClass.id }) else { return }

        var universityClass = normalizedUniversityClass(updatedClass, timestamp: updatedAt)
        universityClass.metadata.updatedAt = updatedAt
        universityClasses[index] = universityClass
        universityClasses = sortedUniversityClasses(universityClasses)
        saveState()
    }

    func archiveUniversityClass(_ classID: EntityID, updatedAt: Date = .now) {
        guard var universityClass = universityClass(id: classID) else { return }

        universityClass.status = .archived
        updateUniversityClass(universityClass, updatedAt: updatedAt)
    }

    func universityClass(id classID: EntityID) -> UniversityClass? {
        universityClasses.first { $0.id == classID }
    }

    @discardableResult
    func addUniversityScheduleSession(
        classID: EntityID,
        weekday: UniversityWeekday,
        startMinuteOfDay: Int,
        endMinuteOfDay: Int,
        locationOverride: String? = nil,
        createdAt: Date = .now
    ) -> UniversityScheduleSession? {
        guard universityClass(id: classID) != nil else { return nil }

        let session = normalizedUniversityScheduleSession(
            UniversityScheduleSession(
                metadata: BaseMetadata(createdAt: createdAt, updatedAt: createdAt),
                classID: classID,
                weekday: weekday,
                startMinuteOfDay: startMinuteOfDay,
                endMinuteOfDay: endMinuteOfDay,
                locationOverride: locationOverride
            ),
            timestamp: createdAt
        )

        universityScheduleSessions.append(session)
        universityScheduleSessions = sortedUniversityScheduleSessions(universityScheduleSessions)
        saveState()
        return session
    }

    func updateUniversityScheduleSession(_ updatedSession: UniversityScheduleSession, updatedAt: Date = .now) {
        guard universityClass(id: updatedSession.classID) != nil,
              let index = universityScheduleSessions.firstIndex(where: { $0.id == updatedSession.id })
        else {
            return
        }

        var session = normalizedUniversityScheduleSession(updatedSession, timestamp: updatedAt)
        session.metadata.updatedAt = updatedAt
        universityScheduleSessions[index] = session
        universityScheduleSessions = sortedUniversityScheduleSessions(universityScheduleSessions)
        saveState()
    }

    func todayClasses(on date: Date? = nil) -> [UniversityScheduledClass] {
        scheduledClasses(on: date ?? currentDate)
    }

    func upcomingClassesThisWeek(from date: Date? = nil) -> [UniversityScheduledClass] {
        let referenceDate = date ?? currentDate
        let referenceWeekday = weekday(for: referenceDate)

        return activeScheduleSessions
            .compactMap { session -> UniversityScheduledClass? in
                guard let universityClass = universityClass(id: session.classID),
                      let occurrenceDate = nextOccurrenceDate(for: session.weekday, referenceDate: referenceDate, referenceWeekday: referenceWeekday)
                else {
                    return nil
                }

                return UniversityScheduledClass(session: session, universityClass: universityClass, occurrenceDate: occurrenceDate)
            }
            .filter { scheduledClass in
                let dayOffset = calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: referenceDate),
                    to: calendar.startOfDay(for: scheduledClass.occurrenceDate)
                ).day ?? 0

                return dayOffset >= 0 && dayOffset < 7
            }
            .sorted(by: sortScheduledClasses)
    }

    private var allUniversityTasks: [AcademicTask] {
        criticalTasks + upcomingDeadlines
    }

    private var gymHealthProgress: GymHealthProgress {
        gymHealthEngine.progress(
            weightGoal: weightGoal,
            weightLogs: weightLogs,
            dailyHealthLogs: dailyHealthLogs,
            referenceDate: currentDate
        )
    }

    private var recentHealthLogs: [DailyHealthLog] {
        let endDay = calendar.startOfDay(for: currentDate)
        let startDay = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay

        return dailyHealthLogs.filter { log in
            let logDay = calendar.startOfDay(for: log.date)
            return logDay >= startDay && logDay <= endDay
        }
    }

    private var moneyTotals: MoneyTotals {
        MoneyTotals(
            arsMinorUnits: moneyAccounts
                .filter { $0.status == .active && $0.currency == .ars }
                .map(\.currentBalance.minorUnits)
                .reduce(0, +),
            usdtMinorUnits: moneyAccounts
                .filter { $0.status == .active && $0.currency == .usdt }
                .map(\.currentBalance.minorUnits)
                .reduce(0, +),
            mockUSDTToARSRate: mockUSDTToARSRate
        )
    }

    private var moneyAccountBalanceItems: [SimpleListItem] {
        sortedMoneyAccounts(moneyAccounts.filter { $0.status == .active })
            .map { account in
                SimpleListItem(
                    id: account.id,
                    title: account.name,
                    detail: account.currency.rawValue,
                    value: formattedMoneyAmount(account.currentBalance)
                )
            }
    }

    private func convertedAmount(_ amount: MoneyAmount, to currency: CurrencyCode) -> MoneyAmount {
        guard amount.currency != currency else { return amount }

        switch (amount.currency, currency) {
        case (.ars, .usdt):
            return MoneyAmount(minorUnits: amount.minorUnits / mockUSDTToARSRate, currency: .usdt)
        case (.usdt, .ars):
            return MoneyAmount(minorUnits: amount.minorUnits * mockUSDTToARSRate, currency: .ars)
        default:
            return MoneyAmount(minorUnits: amount.minorUnits, currency: currency)
        }
    }

    private func sortedMoneyAccounts(_ accounts: [MoneyAccount]) -> [MoneyAccount] {
        accounts.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func formattedMoneyAmount(_ amount: MoneyAmount) -> String {
        switch amount.currency {
        case .ars:
            return "$\(amount.minorUnits.formatted())"
        case .usdt:
            return amount.minorUnits.formatted()
        }
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

    private var activeUniversityClasses: [UniversityClass] {
        sortedUniversityClasses(universityClasses.filter { $0.status == .active })
    }

    private var activeScheduleSessions: [UniversityScheduleSession] {
        sortedUniversityScheduleSessions(
            universityScheduleSessions.filter { session in
                universityClass(id: session.classID)?.status == .active
            }
        )
    }

    private var todayUniversityClasses: [UniversityScheduledClass] {
        todayClasses()
    }

    private var upcomingUniversityClassesThisWeek: [UniversityScheduledClass] {
        upcomingClassesThisWeek()
    }

    private func scheduledClasses(on date: Date) -> [UniversityScheduledClass] {
        let targetWeekday = weekday(for: date)

        return activeScheduleSessions
            .filter { $0.weekday == targetWeekday }
            .compactMap { session in
                guard let universityClass = universityClass(id: session.classID) else { return nil }
                return UniversityScheduledClass(session: session, universityClass: universityClass, occurrenceDate: calendar.startOfDay(for: date))
            }
            .sorted(by: sortScheduledClasses)
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

    private func normalizedUniversityClass(_ universityClass: UniversityClass, timestamp: Date) -> UniversityClass {
        var universityClass = universityClass
        universityClass.name = normalizedRequiredText(universityClass.name, fallback: "Class")
        universityClass.shortName = normalizedOptionalText(universityClass.shortName)
        universityClass.instructor = normalizedOptionalText(universityClass.instructor)
        universityClass.location = normalizedOptionalText(universityClass.location)
        universityClass.notes = normalizedOptionalText(universityClass.notes)
        universityClass.metadata.updatedAt = timestamp
        return universityClass
    }

    private func normalizedUniversityScheduleSession(_ session: UniversityScheduleSession, timestamp: Date) -> UniversityScheduleSession {
        var session = session
        session.startMinuteOfDay = min(clampedMinuteOfDay(session.startMinuteOfDay), (24 * 60) - 2)
        session.endMinuteOfDay = clampedMinuteOfDay(session.endMinuteOfDay)
        if session.endMinuteOfDay <= session.startMinuteOfDay {
            session.endMinuteOfDay = min(session.startMinuteOfDay + 60, (24 * 60) - 1)
        }
        session.locationOverride = normalizedOptionalText(session.locationOverride)
        session.metadata.updatedAt = timestamp
        return session
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

    private func sortedUniversityClasses(_ classes: [UniversityClass]) -> [UniversityClass] {
        classes.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .active
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func sortedUniversityScheduleSessions(_ sessions: [UniversityScheduleSession]) -> [UniversityScheduleSession] {
        sessions.sorted { lhs, rhs in
            if lhs.weekday != rhs.weekday {
                return lhs.weekday < rhs.weekday
            }

            if lhs.startMinuteOfDay != rhs.startMinuteOfDay {
                return lhs.startMinuteOfDay < rhs.startMinuteOfDay
            }

            return lhs.metadata.createdAt < rhs.metadata.createdAt
        }
    }

    private func sortScheduledClasses(_ lhs: UniversityScheduledClass, _ rhs: UniversityScheduledClass) -> Bool {
        if lhs.occurrenceDate != rhs.occurrenceDate {
            return lhs.occurrenceDate < rhs.occurrenceDate
        }

        if lhs.session.startMinuteOfDay != rhs.session.startMinuteOfDay {
            return lhs.session.startMinuteOfDay < rhs.session.startMinuteOfDay
        }

        return lhs.universityClass.name.localizedCaseInsensitiveCompare(rhs.universityClass.name) == .orderedAscending
    }

    private func weekday(for date: Date) -> UniversityWeekday {
        let weekday = calendar.component(.weekday, from: date)
        return UniversityWeekday(rawValue: weekday) ?? .monday
    }

    private func nextOccurrenceDate(for weekday: UniversityWeekday, referenceDate: Date, referenceWeekday: UniversityWeekday) -> Date? {
        let dayOffset = (weekday.rawValue - referenceWeekday.rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: referenceDate))
    }

    private func clampedMinuteOfDay(_ minute: Int) -> Int {
        min(max(minute, 0), (24 * 60) - 1)
    }

    private func normalizedOptionalText(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedRequiredText(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
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

    private var persistedState: PersistedAppState {
        PersistedAppState(
            weightGoal: weightGoal,
            weightLogs: weightLogs,
            dailyHealthLogs: dailyHealthLogs,
            dailyOrderPlan: dailyOrderPlan,
            criticalTasks: criticalTasks,
            upcomingDeadlines: upcomingDeadlines,
            waitingResponses: waitingResponses,
            timeline: timeline,
            universityClasses: universityClasses,
            universityScheduleSessions: universityScheduleSessions,
            moneyAccounts: moneyAccounts,
            moneyTransactions: moneyTransactions
        )
    }

    private func refreshDailyOrder(save shouldSave: Bool) {
        dailyOrderPlan = dailyOrderGenerator.generate(
            progress: gymHealthProgress,
            date: currentDate,
            todayHealth: dailyHealthLog(on: currentDate),
            hasWeightLogToday: weightLog(on: currentDate) != nil,
            existingPlan: dailyOrderPlan
        )

        if shouldSave {
            saveState()
        }
    }

    private func saveState() {
        guard let persistence else { return }

        do {
            try persistence.save(persistedState)
            persistenceError = nil
        } catch let error as AppStatePersistenceError {
            persistenceError = error
        } catch {
            persistenceError = .saveFailed(error.localizedDescription)
        }
    }

    static func live() -> AppStore {
        AppStore(persistence: makeLivePersistence())
    }

    private static func makeLivePersistence() -> AppStatePersisting? {
        do {
            return try JSONFileAppStatePersistence.live()
        } catch {
            return nil
        }
    }
}
