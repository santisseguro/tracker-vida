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
    @Published var moneyAccounts: [MoneyAccount]
    @Published var moneyTransactions: [MoneyTransaction]
    @Published var settingsSections: [SimpleListItem]

    private let calendar: Calendar
    private let mockUSDTToARSRate: Int
    private let persistence: AppStatePersisting?
    private let gymHealthEngine: GymHealthEngine

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
            self.moneyAccounts = restoredState.moneyAccounts
            self.moneyTransactions = restoredState.moneyTransactions
            self.settingsSections = settingsSections
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
        self.moneyAccounts = moneyAccounts
        self.moneyTransactions = moneyTransactions
        self.settingsSections = settingsSections
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
            timeline: timeline
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
        createdAt: Date = .now
    ) -> MoneyAccount {
        let account = MoneyAccount(
            metadata: BaseMetadata(createdAt: createdAt, updatedAt: createdAt),
            name: normalizedRequiredText(name, fallback: "Account"),
            currency: currency,
            currentBalance: MoneyAmount(minorUnits: currentBalance, currency: currency),
            kind: currency == .usdt ? .cryptoWallet : .digitalWallet,
            status: status
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
        date: Date = .now
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
            category: .income(category)
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
        date: Date = .now
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
            category: .expense(category)
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
        date: Date = .now
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
            toAccountID: toAccountID
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
        date: Date = .now
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
            balanceAfter: updatedBalance
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
            moneyAccounts: moneyAccounts,
            moneyTransactions: moneyTransactions
        )
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
