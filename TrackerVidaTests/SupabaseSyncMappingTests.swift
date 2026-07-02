import XCTest
@testable import TrackerVida

final class SupabaseSyncMappingTests: XCTestCase {
    private let ownerID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testMapsGymHealthModelsToDTOsAndBack() {
        let state = makeState()
        let snapshot = makeSnapshot(from: state)
        let restoredState = SupabaseSyncMapper.makePersistedAppState(from: snapshot)

        XCTAssertEqual(snapshot.weightGoal.ownerID, ownerID)
        XCTAssertEqual(snapshot.weightGoal.updatedAt, state.weightGoal.metadata.updatedAt)
        XCTAssertEqual(snapshot.weightGoal.targetWeightKg, state.weightGoal.targetWeightKg)
        XCTAssertEqual(snapshot.weightGoal.gymDayCalorieTarget, state.weightGoal.gymDayCalorieTarget)
        XCTAssertEqual(snapshot.weightGoal.restDayCalorieTarget, state.weightGoal.restDayCalorieTarget)
        XCTAssertEqual(snapshot.weightGoal.targetWorkoutsPerWeek, state.weightGoal.targetWorkoutsPerWeek)

        XCTAssertEqual(snapshot.weightLogs.map(\.id), state.weightLogs.map(\.id))
        XCTAssertEqual(snapshot.weightLogs.first?.logDate, state.weightLogs.first?.date)
        XCTAssertEqual(snapshot.weightLogs.first?.weightKg, state.weightLogs.first?.weightKg)
        XCTAssertEqual(snapshot.weightLogs.first?.source, state.weightLogs.first?.source.source.rawValue)

        XCTAssertEqual(snapshot.dailyHealthLogs.map(\.id), state.dailyHealthLogs.map(\.id))
        XCTAssertEqual(snapshot.dailyHealthLogs.first?.totalCalories, state.dailyHealthLogs.first?.totalCalories)
        XCTAssertEqual(snapshot.dailyHealthLogs.first?.gymAttended, state.dailyHealthLogs.first?.gymAttended)
        XCTAssertEqual(snapshot.dailyHealthLogs.first?.workoutType, state.dailyHealthLogs.first?.workoutType?.rawValue)
        XCTAssertEqual(snapshot.dailyHealthLogs.first?.sleepQuality, state.dailyHealthLogs.first?.sleepQuality?.rawValue)

        XCTAssertEqual(restoredState.weightGoal, state.weightGoal)
        XCTAssertEqual(restoredState.weightLogs.map(\.id), state.weightLogs.map(\.id))
        XCTAssertEqual(restoredState.weightLogs.map(\.date), state.weightLogs.map(\.date))
        XCTAssertEqual(restoredState.weightLogs.map(\.weightKg), state.weightLogs.map(\.weightKg))
        XCTAssertEqual(restoredState.dailyHealthLogs.map(\.id), state.dailyHealthLogs.map(\.id))
        XCTAssertEqual(restoredState.dailyHealthLogs.map(\.totalCalories), state.dailyHealthLogs.map(\.totalCalories))
        XCTAssertEqual(restoredState.dailyHealthLogs.map(\.workoutType), state.dailyHealthLogs.map(\.workoutType))
        XCTAssertEqual(restoredState.dailyHealthLogs.map(\.sleepQuality), state.dailyHealthLogs.map(\.sleepQuality))
    }

    func testMapsUniversityTasksToDTOsAndBack() {
        let state = makeState()
        let snapshot = makeSnapshot(from: state)
        let restoredState = SupabaseSyncMapper.makePersistedAppState(from: snapshot)

        XCTAssertEqual(snapshot.universityTasks.count, state.criticalTasks.count + state.upcomingDeadlines.count)
        XCTAssertTrue(snapshot.universityTasks.allSatisfy { $0.ownerID == ownerID })
        XCTAssertTrue(snapshot.universityTasks.contains { $0.priority == AcademicTaskPriority.critical.rawValue })
        XCTAssertTrue(snapshot.universityTasks.contains { $0.status == AcademicTaskStatus.waitingResponse.rawValue })
        XCTAssertTrue(snapshot.universityTasks.contains { $0.waitingSince != nil })

        let originalTasks = state.criticalTasks + state.upcomingDeadlines
        let restoredTasks = restoredState.criticalTasks + restoredState.upcomingDeadlines

        XCTAssertEqual(Set(restoredTasks.map(\.id)), Set(originalTasks.map(\.id)))
        XCTAssertEqual(restoredState.criticalTasks.map(\.priority), Array(repeating: .critical, count: restoredState.criticalTasks.count))
        XCTAssertTrue(restoredState.upcomingDeadlines.allSatisfy { $0.priority != .critical })

        let waitingTask = restoredTasks.first { $0.status == .waitingResponse }
        XCTAssertEqual(waitingTask?.waitingSince, originalTasks.first { $0.status == .waitingResponse }?.waitingSince)
        XCTAssertEqual(waitingTask?.notes, originalTasks.first { $0.status == .waitingResponse }?.notes)
    }

    func testMapsMoneyAccountsAndTransactionsToDTOsAndBack() {
        let state = makeState()
        let snapshot = makeSnapshot(from: state)
        let restoredState = SupabaseSyncMapper.makePersistedAppState(from: snapshot)

        XCTAssertEqual(snapshot.moneyAccounts.map(\.id), state.moneyAccounts.map(\.id))
        XCTAssertEqual(snapshot.moneyAccounts.first?.currency, state.moneyAccounts.first?.currency.rawValue)
        XCTAssertEqual(snapshot.moneyAccounts.first?.currentBalanceMinorUnits, state.moneyAccounts.first?.currentBalance.minorUnits)
        XCTAssertEqual(snapshot.moneyAccounts.first?.updatedAt, state.moneyAccounts.first?.metadata.updatedAt)

        let incomeDTO = snapshot.moneyTransactions.first { $0.kind == MoneyTransactionKind.income.rawValue }
        let expenseDTO = snapshot.moneyTransactions.first { $0.kind == MoneyTransactionKind.expense.rawValue }
        let transferDTO = snapshot.moneyTransactions.first { $0.kind == MoneyTransactionKind.transfer.rawValue }
        let adjustmentDTO = snapshot.moneyTransactions.first { $0.kind == MoneyTransactionKind.balanceAdjustment.rawValue }

        XCTAssertEqual(incomeDTO?.categoryKind, "income")
        XCTAssertEqual(incomeDTO?.categoryLabel, IncomeCategory.trabajo.rawValue)
        XCTAssertEqual(expenseDTO?.categoryKind, "expense")
        XCTAssertEqual(expenseDTO?.categoryLabel, ExpenseCategory.comida.rawValue)
        XCTAssertNil(transferDTO?.categoryKind)
        XCTAssertNil(transferDTO?.categoryLabel)
        XCTAssertNotNil(adjustmentDTO?.balanceBeforeMinorUnits)
        XCTAssertNotNil(adjustmentDTO?.balanceAfterMinorUnits)

        XCTAssertEqual(Set(restoredState.moneyAccounts.map(\.id)), Set(state.moneyAccounts.map(\.id)))
        XCTAssertEqual(Set(restoredState.moneyTransactions.map(\.id)), Set(state.moneyTransactions.map(\.id)))

        let restoredIncome = restoredState.moneyTransactions.first { $0.id == incomeDTO?.id }
        let restoredExpense = restoredState.moneyTransactions.first { $0.id == expenseDTO?.id }
        let restoredAdjustment = restoredState.moneyTransactions.first { $0.id == adjustmentDTO?.id }

        XCTAssertEqual(restoredIncome?.category?.label, IncomeCategory.trabajo.rawValue)
        XCTAssertEqual(restoredExpense?.category?.label, ExpenseCategory.comida.rawValue)
        XCTAssertEqual(restoredAdjustment?.balanceBefore?.minorUnits, adjustmentDTO?.balanceBeforeMinorUnits)
        XCTAssertEqual(restoredAdjustment?.balanceAfter?.minorUnits, adjustmentDTO?.balanceAfterMinorUnits)
    }

    func testMapsDailyAIOrderChecklistStateToDTOsAndBack() {
        let state = makeState()
        let snapshot = makeSnapshot(from: state)
        let restoredState = SupabaseSyncMapper.makePersistedAppState(from: snapshot)

        XCTAssertEqual(snapshot.dailyOrderPlan.id, state.dailyOrderPlan.id)
        XCTAssertEqual(snapshot.dailyOrderPlan.ownerID, ownerID)
        XCTAssertEqual(snapshot.dailyOrderPlan.promptVersion, state.dailyOrderPlan.promptVersion)
        XCTAssertEqual(snapshot.dailyOrders.map(\.id), state.dailyOrderPlan.orders.map(\.id))
        XCTAssertEqual(snapshot.dailyChecklistItems.count, state.dailyOrderPlan.orders.flatMap(\.checklist).count)

        let originalItem = state.dailyOrderPlan.orders[0].checklist[0]
        let itemDTO = snapshot.dailyChecklistItems.first { $0.id == originalItem.id }
        XCTAssertEqual(itemDTO?.status, DailyOrderStatus.done.rawValue)
        XCTAssertEqual(itemDTO?.priority, originalItem.priority.rawValue)
        XCTAssertEqual(itemDTO?.rationale, originalItem.rationale)

        let restoredItem = restoredState.dailyOrderPlan.orders[0].checklist.first { $0.id == originalItem.id }
        XCTAssertEqual(restoredState.dailyOrderPlan.id, state.dailyOrderPlan.id)
        XCTAssertEqual(restoredState.dailyOrderPlan.orders.map(\.id), state.dailyOrderPlan.orders.map(\.id))
        XCTAssertEqual(restoredItem?.status, .done)
        XCTAssertEqual(restoredItem?.title, originalItem.title)
        XCTAssertEqual(restoredItem?.kind, originalItem.kind)
        XCTAssertEqual(restoredItem?.area, originalItem.area)
    }

    func testSupabaseSnapshotDoesNotStoreDerivedDashboardOrCalculationValues() throws {
        let snapshot = makeSnapshot(from: makeState())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(snapshot)
        let json = String(decoding: encoded, as: UTF8.self)

        XCTAssertFalse(json.contains("dashboardState"))
        XCTAssertFalse(json.contains("gymHealthState"))
        XCTAssertFalse(json.contains("moneyTotals"))
        XCTAssertFalse(json.contains("mockUSDTToARSRate"))
        XCTAssertFalse(json.contains("weeklyCalories"))
        XCTAssertFalse(json.contains("weeklyGym"))
        XCTAssertFalse(json.contains("GymHealthProgress"))
        XCTAssertFalse(json.contains("currentWeightKg"))
        XCTAssertFalse(json.contains("trackStatus"))
    }

    func testRoundTripPreservesIDsDatesAmountsCategoriesStatusesAndChecklistCompletion() {
        let state = makeState()
        let snapshot = makeSnapshot(from: state)
        let restoredState = SupabaseSyncMapper.makePersistedAppState(
            from: snapshot,
            waitingResponses: state.waitingResponses,
            timeline: state.timeline
        )

        XCTAssertEqual(restoredState.schemaVersion, state.schemaVersion)
        XCTAssertEqual(restoredState.weightGoal.id, state.weightGoal.id)
        XCTAssertEqual(restoredState.weightGoal.metadata.updatedAt, state.weightGoal.metadata.updatedAt)
        XCTAssertEqual(restoredState.weightLogs.map(\.id), state.weightLogs.map(\.id))
        XCTAssertEqual(restoredState.dailyHealthLogs.map(\.date), state.dailyHealthLogs.map(\.date))
        XCTAssertEqual(restoredState.criticalTasks.map(\.status), state.criticalTasks.map(\.status))
        XCTAssertEqual(Set(restoredState.moneyAccounts.map(\.currentBalance.minorUnits)), Set(state.moneyAccounts.map(\.currentBalance.minorUnits)))
        XCTAssertEqual(Set(restoredState.moneyTransactions.map(\.amount.minorUnits)), Set(state.moneyTransactions.map(\.amount.minorUnits)))

        let originalCategories = state.moneyTransactions.compactMap { $0.category?.label }.sorted()
        let restoredCategories = restoredState.moneyTransactions.compactMap { $0.category?.label }.sorted()
        XCTAssertEqual(restoredCategories, originalCategories)

        let originalChecklistStatuses = state.dailyOrderPlan.orders.flatMap(\.checklist).map(\.status)
        let restoredChecklistStatuses = restoredState.dailyOrderPlan.orders.flatMap(\.checklist).map(\.status)
        XCTAssertEqual(restoredChecklistStatuses, originalChecklistStatuses)

        XCTAssertEqual(restoredState.waitingResponses, state.waitingResponses)
        XCTAssertEqual(restoredState.timeline, state.timeline)
    }

    private func makeSnapshot(from state: PersistedAppState) -> SupabaseAppStateDTO {
        SupabaseSyncMapper.makeSnapshot(
            ownerID: ownerID,
            state: state,
            displayName: "Santi",
            timezoneIdentifier: "America/Argentina/Buenos_Aires",
            ownerCreatedAt: MockData.today,
            ownerUpdatedAt: MockData.today
        )
    }

    private func makeState() -> PersistedAppState {
        var plan = MockData.dailyOrderPlan
        plan.orders[0].checklist[0].status = .done

        var waitingTask = MockData.upcomingDeadlines[0]
        waitingTask.status = .waitingResponse
        waitingTask.waitingSince = MockData.makeDate(year: 2026, month: 6, day: 25)
        waitingTask.notes = "Waiting for faculty response"

        let adjustment = MoneyTransaction(
            metadata: BaseMetadata(createdAt: MockData.today, updatedAt: MockData.today),
            date: MockData.today,
            title: "QA balance correction",
            kind: .balanceAdjustment,
            amount: MoneyAmount(minorUnits: 5_000, currency: .ars),
            toAccountID: MockData.accountARS,
            balanceBefore: MoneyAmount(minorUnits: 77_400, currency: .ars),
            balanceAfter: MoneyAmount(minorUnits: 82_400, currency: .ars),
            notes: "Manual recount"
        )

        return PersistedAppState(
            schemaVersion: 1,
            weightGoal: MockData.weightGoal,
            weightLogs: MockData.weightLogs,
            dailyHealthLogs: MockData.dailyHealthLogs,
            dailyOrderPlan: plan,
            criticalTasks: MockData.criticalTasks,
            upcomingDeadlines: [waitingTask] + Array(MockData.upcomingDeadlines.dropFirst()),
            waitingResponses: MockData.waitingResponses,
            timeline: MockData.timeline,
            moneyAccounts: MockData.moneyAccounts,
            moneyTransactions: MockData.moneyTransactions + [adjustment]
        )
    }
}
