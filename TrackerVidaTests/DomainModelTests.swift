import XCTest
@testable import TrackerVida

final class DomainModelTests: XCTestCase {
    func testGymHealthMockSummaries() {
        XCTAssertEqual(MockData.dailyHealthLogs.gymAttendanceCount, 4)
        XCTAssertEqual(MockData.weightLogs.latest?.weightKg, 81.8)
        XCTAssertGreaterThan(MockData.dailyHealthLogs.averageSleepHours, 7)
    }

    func testMoneySignedAmountsAndCategories() {
        let income = MockData.moneyTransactions[0]
        let expense = MockData.moneyTransactions[1]
        let transfer = MockData.moneyTransactions[2]

        XCTAssertEqual(income.signedMinorUnits, 180_000)
        XCTAssertEqual(expense.signedMinorUnits, -11_500)
        XCTAssertEqual(transfer.signedMinorUnits, 0)
        XCTAssertEqual(income.category?.label, "Trabajo")
        XCTAssertEqual(expense.category?.label, "Comida")
        XCTAssertNil(transfer.category)
    }

    @MainActor
    func testStoreAddsMoneyAccount() {
        let store = AppStore(currentDate: MockData.today)

        let account = store.addMoneyAccount(
            name: "Mercado Pago",
            currency: .ars,
            currentBalance: 25_000,
            status: .active,
            createdAt: MockData.today
        )

        XCTAssertEqual(store.moneyAccount(id: account.id)?.name, "Mercado Pago")
        XCTAssertEqual(store.moneyAccount(id: account.id)?.currentBalance.minorUnits, 25_000)
        XCTAssertEqual(store.moneyState.activeAccounts.count, 4)
    }

    @MainActor
    func testStoreEditsMoneyAccount() {
        let store = AppStore(currentDate: MockData.today)
        var account = store.moneyAccounts[0]

        account.name = "Efectivo diario"
        account.currentBalance = MoneyAmount(minorUnits: 90_000, currency: .ars)
        account.status = .archived

        store.updateMoneyAccount(account, updatedAt: MockData.today)

        XCTAssertEqual(store.moneyAccount(id: account.id)?.name, "Efectivo diario")
        XCTAssertEqual(store.moneyAccount(id: account.id)?.currentBalance.minorUnits, 90_000)
        XCTAssertEqual(store.moneyAccount(id: account.id)?.status, .archived)
        XCTAssertEqual(store.moneyState.activeAccounts.count, 2)
    }

    @MainActor
    func testStoreAddsIncomeAndUpdatesBalance() {
        let store = AppStore(currentDate: MockData.today)
        let accountID = MockData.accountBankARS

        let transaction = store.addIncomeTransaction(
            title: "Pago extra",
            amount: 40_000,
            toAccountID: accountID,
            category: .trabajo,
            date: MockData.today
        )

        XCTAssertEqual(store.moneyAccount(id: accountID)?.currentBalance.minorUnits, 458_900)
        XCTAssertEqual(transaction?.category?.label, "Trabajo")
        XCTAssertEqual(transaction?.fromAccountID, nil)
        XCTAssertEqual(transaction?.toAccountID, accountID)
    }

    @MainActor
    func testStoreAddsExpenseAndUpdatesBalance() {
        let store = AppStore(currentDate: MockData.today)
        let accountID = MockData.accountARS

        let transaction = store.addExpenseTransaction(
            title: "Colectivo",
            amount: 2_500,
            fromAccountID: accountID,
            category: .transporte,
            date: MockData.today
        )

        XCTAssertEqual(store.moneyAccount(id: accountID)?.currentBalance.minorUnits, 79_900)
        XCTAssertEqual(transaction?.category?.label, "Transporte")
        XCTAssertEqual(transaction?.fromAccountID, accountID)
        XCTAssertEqual(transaction?.toAccountID, nil)
    }

    @MainActor
    func testStoreTransferUpdatesBothAccounts() {
        let store = AppStore(currentDate: MockData.today)

        let transaction = store.addTransferTransaction(
            title: "Cash to bank",
            amount: 10_000,
            fromAccountID: MockData.accountARS,
            toAccountID: MockData.accountBankARS,
            date: MockData.today
        )

        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 72_400)
        XCTAssertEqual(store.moneyAccount(id: MockData.accountBankARS)?.currentBalance.minorUnits, 428_900)
        XCTAssertNil(transaction?.category)
    }

    @MainActor
    func testStoreBalanceAdjustmentStoresDifference() {
        let store = AppStore(currentDate: MockData.today)

        let transaction = store.addBalanceAdjustmentTransaction(
            title: "Cash recount",
            accountID: MockData.accountARS,
            newBalance: 80_000,
            date: MockData.today
        )

        XCTAssertEqual(store.moneyAccount(id: MockData.accountARS)?.currentBalance.minorUnits, 80_000)
        XCTAssertEqual(transaction?.amount.minorUnits, -2_400)
        XCTAssertEqual(transaction?.balanceBefore?.minorUnits, 82_400)
        XCTAssertEqual(transaction?.balanceAfter?.minorUnits, 80_000)
        XCTAssertNil(transaction?.category)
    }

    @MainActor
    func testDashboardMoneyTotalsUpdateFromSharedState() {
        let store = AppStore(currentDate: MockData.today)

        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 501_300)
        XCTAssertEqual(store.dashboardState.moneyTotals.usdtMinorUnits, 1_240)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentMinorUnits, 1_741_300)
        XCTAssertEqual(store.dashboardState.moneyTotals.dashboardDisplay, "$1741K")

        store.addIncomeTransaction(
            title: "Reembolso",
            amount: 1_200,
            toAccountID: MockData.accountBankARS,
            category: .reembolso,
            date: MockData.today
        )

        XCTAssertEqual(store.moneyState.totals.arsMinorUnits, 502_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsMinorUnits, 502_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.arsEquivalentMinorUnits, 1_742_500)
        XCTAssertEqual(store.dashboardState.moneyTotals.dashboardDisplay, "$1742K")
    }

    func testDailyOrderCompletionRatio() {
        XCTAssertEqual(MockData.dailyOrderPlan.completionRatio, 0)
        XCTAssertEqual(MockData.dailyOrderPlan.orders.first?.checklist.count, 3)
    }

    func testPersistedAppStateEncodesAndDecodes() throws {
        var plan = MockData.dailyOrderPlan
        plan.orders[0].checklist[0].status = .done

        let state = PersistedAppState(
            weightGoal: MockData.weightGoal,
            weightLogs: MockData.weightLogs,
            dailyHealthLogs: MockData.dailyHealthLogs,
            dailyOrderPlan: plan,
            criticalTasks: MockData.criticalTasks,
            upcomingDeadlines: MockData.upcomingDeadlines,
            waitingResponses: MockData.waitingResponses,
            timeline: MockData.timeline,
            moneyAccounts: MockData.moneyAccounts,
            moneyTransactions: MockData.moneyTransactions
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(state)
        let decoded = try decoder.decode(PersistedAppState.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, state.schemaVersion)
        XCTAssertEqual(decoded.weightGoal.targetWeightKg, state.weightGoal.targetWeightKg)
        XCTAssertEqual(decoded.weightLogs.map(\.id), state.weightLogs.map(\.id))
        XCTAssertEqual(decoded.dailyHealthLogs.count, state.dailyHealthLogs.count)
        XCTAssertEqual(decoded.dailyOrderPlan.orders[0].checklist[0].status, .done)
        XCTAssertEqual(decoded.criticalTasks.map(\.title), state.criticalTasks.map(\.title))
        XCTAssertEqual(decoded.moneyAccounts.map(\.name), state.moneyAccounts.map(\.name))
        XCTAssertEqual(decoded.moneyTransactions.map(\.title), state.moneyTransactions.map(\.title))
    }

    @MainActor
    func testStoreUsesSeedDataWhenNoSavedStateExists() {
        let persistence = InMemoryAppStatePersistence(state: nil)

        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        XCTAssertEqual(store.weightGoal.targetWeightKg, MockData.weightGoal.targetWeightKg)
        XCTAssertEqual(store.weightLogs.count, MockData.weightLogs.count)
        XCTAssertEqual(store.criticalTasks.count, MockData.criticalTasks.count)
        XCTAssertEqual(store.moneyAccounts.count, MockData.moneyAccounts.count)
        XCTAssertEqual(store.dailyOrdersState.completedItems, 0)
    }

    @MainActor
    func testStoreRestoresSavedState() {
        var plan = MockData.dailyOrderPlan
        plan.orders[0].checklist[0].status = .done

        var task = MockData.criticalTasks[0]
        task.status = .completed
        task.completedAt = MockData.today

        var account = MockData.moneyAccounts[0]
        account.name = "Saved cash"
        account.currentBalance = MoneyAmount(minorUnits: 123_456, currency: .ars)

        let savedState = PersistedAppState(
            weightGoal: WeightGoal(
                metadata: MockData.weightGoal.metadata,
                targetWeightKg: 76,
                startWeightKg: MockData.weightGoal.startWeightKg,
                startDate: MockData.weightGoal.startDate,
                targetDate: MockData.weightGoal.targetDate,
                isActive: true
            ),
            weightLogs: [
                WeightLog(
                    metadata: BaseMetadata(createdAt: MockData.today, updatedAt: MockData.today),
                    date: MockData.today,
                    weightKg: 79.9,
                    source: MockData.healthSource
                )
            ],
            dailyHealthLogs: MockData.dailyHealthLogs,
            dailyOrderPlan: plan,
            criticalTasks: [task],
            upcomingDeadlines: MockData.upcomingDeadlines,
            waitingResponses: MockData.waitingResponses,
            timeline: MockData.timeline,
            moneyAccounts: [account],
            moneyTransactions: MockData.moneyTransactions
        )
        let persistence = InMemoryAppStatePersistence(state: savedState)

        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        XCTAssertEqual(store.weightGoal.targetWeightKg, 76)
        XCTAssertEqual(store.weightLogs.first?.weightKg, 79.9)
        XCTAssertEqual(store.dailyOrdersState.completedItems, 1)
        XCTAssertEqual(store.criticalTasks.first?.status, .completed)
        XCTAssertEqual(store.moneyAccounts.first?.name, "Saved cash")
        XCTAssertEqual(store.moneyAccounts.first?.currentBalance.minorUnits, 123_456)
    }

    @MainActor
    func testStoreSavesAfterWorkflowMutation() {
        let persistence = InMemoryAppStatePersistence(state: nil)
        let store = AppStore(currentDate: MockData.today, persistence: persistence)

        store.upsertWeightLog(date: MockData.today, weightKg: 80.2, enteredAt: MockData.today)

        XCTAssertEqual(persistence.savedStates.count, 1)
        XCTAssertEqual(persistence.savedStates.last?.weightLogs.latest?.weightKg, 80.2)
    }

    func testGymHealthV1ChoiceSets() {
        XCTAssertEqual(WorkoutType.allCases.map(\.rawValue), ["Push", "Pull", "Legs", "Full Body", "Cardio", "Other"])
        XCTAssertEqual(SleepQuality.allCases.map(\.rawValue), ["Good", "Normal", "Bad"])
    }

    func testUniversityV1ChoiceSets() {
        XCTAssertEqual(AcademicTaskCategory.allCases.map(\.rawValue), ["Académico", "Trámite", "Documento", "Deadline", "Email", "Otro"])
        XCTAssertEqual(AcademicTaskPriority.allCases.map(\.rawValue), ["Crítica", "Alta", "Media", "Baja"])
        XCTAssertEqual(AcademicTaskStatus.allCases.map(\.rawValue), ["Pendiente", "En progreso", "Esperando respuesta", "Completada"])
    }

    @MainActor
    func testStoreTogglesDailyChecklistItems() {
        let store = AppStore()
        let itemID = store.dailyOrderPlan.orders[0].checklist[0].id

        XCTAssertEqual(store.dailyOrdersState.completedItems, 0)

        store.toggleDailyChecklistItem(itemID)

        XCTAssertEqual(store.dailyOrderPlan.orders[0].checklist[0].status, .done)
        XCTAssertEqual(store.dailyOrdersState.completedItems, 1)
        XCTAssertGreaterThan(store.dashboardState.dailyOrderPlan.completionRatio, 0)
    }

    @MainActor
    func testStoreMarksAcademicTasksCompleted() {
        let store = AppStore()
        let taskID = store.criticalTasks[0].id

        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 2)

        store.markAcademicTaskCompleted(taskID)

        XCTAssertEqual(store.criticalTasks[0].status, .completed)
        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 1)
        XCTAssertEqual(store.universityState.activeCriticalTasks.count, 1)
    }

    @MainActor
    func testStoreAddsUniversityTask() {
        let store = AppStore(currentDate: MockData.today)

        let task = store.addUniversityTask(
            title: "Enviar certificado",
            category: .document,
            status: .pending,
            priority: .medium,
            dueDate: MockData.makeDate(year: 2026, month: 7, day: 8),
            notes: "Subir PDF",
            waitingSince: nil,
            createdAt: MockData.today
        )

        XCTAssertEqual(store.universityTask(id: task.id)?.title, "Enviar certificado")
        XCTAssertEqual(store.universityState.upcomingDeadlines.last?.category, .document)
    }

    @MainActor
    func testStoreEditsUniversityTask() {
        let store = AppStore(currentDate: MockData.today)
        var task = store.upcomingDeadlines[0]

        task.title = "Lectura Economia final"
        task.category = .academic
        task.priority = .high
        task.notes = "Leer capitulos 2 y 3"

        store.updateUniversityTask(task, updatedAt: MockData.today)

        let updatedTask = store.universityTask(id: task.id)
        XCTAssertEqual(updatedTask?.title, "Lectura Economia final")
        XCTAssertEqual(updatedTask?.priority, .high)
        XCTAssertEqual(updatedTask?.notes, "Leer capitulos 2 y 3")
    }

    @MainActor
    func testStoreChangesUniversityTaskStatus() {
        let store = AppStore(currentDate: MockData.today)
        let taskID = store.upcomingDeadlines[0].id

        store.updateAcademicTaskStatus(taskID, status: .inProgress, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: taskID)?.status, .inProgress)
        XCTAssertNil(store.universityTask(id: taskID)?.completedAt)
    }

    @MainActor
    func testStoreChangesUniversityTaskPriorityAndDashboardCriticalCount() {
        let store = AppStore(currentDate: MockData.today)
        let taskID = store.upcomingDeadlines[0].id

        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 2)

        store.updateAcademicTaskPriority(taskID, priority: .critical, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: taskID)?.priority, .critical)
        XCTAssertEqual(store.dashboardState.activeCriticalTasks.count, 3)
        XCTAssertEqual(store.universityState.activeCriticalTasks.count, 3)
    }

    @MainActor
    func testStoreSetsWaitingResponseDate() {
        let store = AppStore(currentDate: MockData.today)
        let taskID = store.upcomingDeadlines[0].id
        let waitingSince = MockData.makeDate(year: 2026, month: 6, day: 25)

        store.updateAcademicTaskStatus(taskID, status: .waitingResponse, waitingSince: waitingSince, updatedAt: MockData.today)

        XCTAssertEqual(store.universityTask(id: taskID)?.status, .waitingResponse)
        XCTAssertEqual(store.universityTask(id: taskID)?.waitingSince, waitingSince)
        XCTAssertEqual(store.universityState.waitingResponses.first?.title, "Lectura Economia")
    }

    @MainActor
    func testStoreUpdatesTodaysWeight() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertWeightLog(date: MockData.today, weightKg: 80.4, enteredAt: MockData.today)

        XCTAssertEqual(store.weightLog(on: MockData.today)?.weightKg, 80.4)
        XCTAssertEqual(store.dashboardState.latestWeight?.weightKg, 80.4)
        XCTAssertEqual(store.gymHealthState.latestWeight?.weightKg, 80.4)
    }

    @MainActor
    func testStoreUpdatesTodaysCalories() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: 2150,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: nil,
            sleepQuality: nil,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.todayHealth?.totalCalories, 2150)
        XCTAssertEqual(store.gymHealthState.todayHealth?.totalCalories, 2150)
    }

    @MainActor
    func testStoreUpdatesTodaysGymAttendance() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: nil,
            gymAttended: true,
            workoutDurationMinutes: 46,
            workoutType: .fullBody,
            sleepHours: nil,
            sleepQuality: nil,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.todayHealth?.gymAttended, true)
        XCTAssertEqual(store.gymHealthState.todayHealth?.workoutDurationMinutes, 46)
        XCTAssertEqual(store.gymHealthState.todayHealth?.workoutType, .fullBody)
        XCTAssertNil(store.dashboardState.todayHealth?.lateEntry)
    }

    @MainActor
    func testStoreUpdatesTodaysSleep() {
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: MockData.today,
            totalCalories: nil,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: 8.0,
            sleepQuality: .normal,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.todayHealth?.sleepHours, 8.0)
        XCTAssertEqual(store.gymHealthState.todayHealth?.sleepQuality, .normal)
        XCTAssertNil(store.dashboardState.todayHealth?.lateEntry)
    }

    @MainActor
    func testStoreMarksPreviousDayHealthEntriesAsLate() {
        let previousDate = MockData.makeDate(year: 2026, month: 6, day: 20)
        let store = AppStore(currentDate: MockData.today)

        store.upsertWeightLog(date: previousDate, weightKg: 83.1, enteredAt: MockData.today)
        store.upsertDailyHealthLog(
            date: previousDate,
            totalCalories: 2400,
            gymAttended: false,
            workoutDurationMinutes: nil,
            workoutType: nil,
            sleepHours: 6.5,
            sleepQuality: .bad,
            enteredAt: MockData.today
        )

        XCTAssertTrue(store.weightLog(on: previousDate)?.lateEntry?.isLateEntry == true)
        XCTAssertTrue(store.dailyHealthLog(on: previousDate)?.lateEntry?.isLateEntry == true)
        XCTAssertEqual(store.dailyHealthLog(on: previousDate)?.sleepQuality, .bad)
    }

    @MainActor
    func testWeeklyHealthSummariesUseRecentSevenDays() {
        let oldDate = MockData.makeDate(year: 2026, month: 6, day: 20)
        let store = AppStore(currentDate: MockData.today)

        store.upsertDailyHealthLog(
            date: oldDate,
            totalCalories: 9_999,
            gymAttended: true,
            workoutDurationMinutes: 60,
            workoutType: .push,
            sleepHours: 10,
            sleepQuality: .good,
            enteredAt: MockData.today
        )

        XCTAssertEqual(store.dashboardState.weeklyGymCount, 4)
        XCTAssertEqual(store.gymHealthState.gymAttendance, 4)
        XCTAssertEqual(store.gymHealthState.weeklyCalories, 13_790)
    }
}

private final class InMemoryAppStatePersistence: AppStatePersisting {
    var state: PersistedAppState?
    var savedStates: [PersistedAppState] = []

    init(state: PersistedAppState?) {
        self.state = state
    }

    func load() throws -> PersistedAppState? {
        state
    }

    func save(_ state: PersistedAppState) throws {
        savedStates.append(state)
        self.state = state
    }
}
