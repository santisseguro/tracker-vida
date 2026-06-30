import Foundation

enum MockData {
    static let calendar = Calendar(identifier: .gregorian)

    static let today = makeDate(year: 2026, month: 6, day: 28)
    static let baseMetadata = BaseMetadata(createdAt: today, updatedAt: today)

    static let healthSource = HealthSourceMetadata(source: .manual)

    static let weightGoal = WeightGoal(
        metadata: baseMetadata,
        targetWeightKg: 78,
        startWeightKg: 84,
        startDate: makeDate(year: 2026, month: 6, day: 1),
        targetDate: makeDate(year: 2026, month: 9, day: 1),
        isActive: true
    )

    static let weightLogs: [WeightLog] = [
        WeightLog(
            metadata: BaseMetadata(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, createdAt: today, updatedAt: today),
            date: makeDate(year: 2026, month: 6, day: 21),
            weightKg: 82.9,
            source: healthSource
        ),
        WeightLog(
            metadata: BaseMetadata(id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!, createdAt: today, updatedAt: today),
            date: today,
            weightKg: 81.8,
            source: healthSource,
            lateEntry: LateEntryMetadata(isLateEntry: false, originalEntryDate: today, enteredAt: today)
        )
    ]

    static let dailyHealthLogs: [DailyHealthLog] = [
        DailyHealthLog(metadata: BaseMetadata(), date: makeDate(year: 2026, month: 6, day: 23), totalCalories: 2380, gymAttended: true, workoutDurationMinutes: 58, workoutType: .push, sleepHours: 7.1, sleepQuality: .good, source: healthSource),
        DailyHealthLog(metadata: BaseMetadata(), date: makeDate(year: 2026, month: 6, day: 24), totalCalories: 2210, gymAttended: true, workoutDurationMinutes: 50, workoutType: .pull, sleepHours: 6.4, sleepQuality: .normal, source: healthSource),
        DailyHealthLog(metadata: BaseMetadata(), date: makeDate(year: 2026, month: 6, day: 25), totalCalories: 2490, gymAttended: false, sleepHours: 7.8, sleepQuality: .good, source: healthSource),
        DailyHealthLog(metadata: BaseMetadata(), date: makeDate(year: 2026, month: 6, day: 26), totalCalories: 2320, gymAttended: true, workoutDurationMinutes: 62, workoutType: .legs, sleepHours: 6.9, sleepQuality: .good, source: healthSource),
        DailyHealthLog(metadata: BaseMetadata(), date: makeDate(year: 2026, month: 6, day: 27), totalCalories: 2550, gymAttended: true, workoutDurationMinutes: 42, workoutType: .cardio, sleepHours: 7.4, sleepQuality: .good, source: healthSource),
        DailyHealthLog(metadata: BaseMetadata(), date: today, totalCalories: 1840, gymAttended: false, sleepHours: 7.2, sleepQuality: .good, source: healthSource)
    ]

    static let dailyOrderPlan = AIGeneratedDailyOrderPlan(
        metadata: baseMetadata,
        date: today,
        source: .aiGenerated,
        generatedAt: today,
        promptVersion: "mock-v1",
        summary: "Prioritize recovery, two critical university tasks, and a quick money review.",
        orders: [
            DailyOrder(
                metadata: baseMetadata,
                title: "Health order",
                area: .gymHealth,
                status: .inProgress,
                priority: .high,
                checklist: [
                    DailyChecklistItem(title: "Hit 2,300 calories by dinner", kind: .task, area: .gymHealth, status: .inProgress, priority: .high),
                    DailyChecklistItem(title: "30 minute cardio reset", kind: .task, area: .gymHealth, status: .pending, priority: .medium),
                    DailyChecklistItem(title: "Sleep target: 7.5 hours", kind: .reminder, area: .gymHealth, status: .pending, priority: .medium)
                ],
                sourceEntityIDs: []
            )
        ]
    )

    static let criticalTasks: [AcademicTask] = [
        AcademicTask(metadata: BaseMetadata(), courseID: nil, title: "Entrega Algebra", category: .deadline, status: .pending, priority: .critical, dueDate: today, links: []),
        AcademicTask(metadata: BaseMetadata(), courseID: nil, title: "Parcial Programacion", category: .academic, status: .inProgress, priority: .critical, dueDate: makeDate(year: 2026, month: 6, day: 29), links: [])
    ]

    static let upcomingDeadlines: [AcademicTask] = [
        AcademicTask(metadata: BaseMetadata(), courseID: nil, title: "Lectura Economia", category: .academic, status: .pending, priority: .medium, dueDate: makeDate(year: 2026, month: 7, day: 1), links: []),
        AcademicTask(metadata: BaseMetadata(), courseID: nil, title: "TP Diseno", category: .academic, status: .pending, priority: .medium, dueDate: makeDate(year: 2026, month: 7, day: 3), links: []),
        AcademicTask(metadata: BaseMetadata(), courseID: nil, title: "Resumen Historia", category: .academic, status: .pending, priority: .low, dueDate: makeDate(year: 2026, month: 7, day: 5), links: [])
    ]

    static let waitingResponses = [
        SimpleListItem(title: "Email profesor de Algebra", detail: "Consulta de recuperatorio", value: "Open"),
        SimpleListItem(title: "Grupo Programacion", detail: "Confirmar reparto del TP", value: "Open")
    ]

    static let timeline = [
        SimpleListItem(title: "Finish Algebra draft", detail: "Today", value: "Focus"),
        SimpleListItem(title: "Programacion review block", detail: "Mon", value: "Plan"),
        SimpleListItem(title: "Economia reading checkpoint", detail: "Wed", value: "Read")
    ]

    static let accountARS = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    static let accountBankARS = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
    static let accountUSDT = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!

    static let moneyAccounts = [
        MoneyAccount(metadata: BaseMetadata(id: accountARS), name: "Efectivo ARS", currency: .ars, currentBalance: MoneyAmount(minorUnits: 82_400, currency: .ars), kind: .cash, status: .active),
        MoneyAccount(metadata: BaseMetadata(id: accountBankARS), name: "Banco ARS", currency: .ars, currentBalance: MoneyAmount(minorUnits: 418_900, currency: .ars), kind: .bank, status: .active),
        MoneyAccount(metadata: BaseMetadata(id: accountUSDT), name: "USDT Wallet", currency: .usdt, currentBalance: MoneyAmount(minorUnits: 1_240, currency: .usdt), kind: .cryptoWallet, status: .active)
    ]

    static let moneyTransactions = [
        MoneyTransaction(metadata: BaseMetadata(), date: today, title: "Pago trabajo freelance", kind: .income, amount: MoneyAmount(minorUnits: 180_000, currency: .ars), toAccountID: accountBankARS, category: .income(.trabajo)),
        MoneyTransaction(metadata: BaseMetadata(), date: today, title: "Almuerzo", kind: .expense, amount: MoneyAmount(minorUnits: 11_500, currency: .ars), fromAccountID: accountARS, category: .expense(.comida)),
        MoneyTransaction(metadata: BaseMetadata(), date: makeDate(year: 2026, month: 6, day: 27), title: "ARS to USDT", kind: .transfer, amount: MoneyAmount(minorUnits: 150, currency: .usdt), fromAccountID: accountBankARS, toAccountID: accountUSDT)
    ]

    static let settingsSections = [
        SimpleListItem(title: "Privacy", detail: "Local-first data, no external services connected.", value: "Ready"),
        SimpleListItem(title: "Health sources", detail: "Manual entries active. HealthKit reserved for later.", value: "Manual"),
        SimpleListItem(title: "Money defaults", detail: "ARS and USDT enabled for v1.", value: "Configured"),
        SimpleListItem(title: "AI assistance", detail: "AI previews are mock-only in this build.", value: "Mock")
    ]

    static func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}

struct SimpleListItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var value: String
}
