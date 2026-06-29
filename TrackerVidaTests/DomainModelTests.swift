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

    func testDailyOrderCompletionRatio() {
        XCTAssertEqual(MockData.dailyOrderPlan.completionRatio, 0)
        XCTAssertEqual(MockData.dailyOrderPlan.orders.first?.checklist.count, 3)
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
}
