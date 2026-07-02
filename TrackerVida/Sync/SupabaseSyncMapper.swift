import Foundation

enum SupabaseSyncMapper {
    static func makeSnapshot(
        ownerID: EntityID,
        state: PersistedAppState,
        displayName: String? = nil,
        timezoneIdentifier: String = TimeZone.current.identifier,
        ownerCreatedAt: Date,
        ownerUpdatedAt: Date
    ) -> SupabaseAppStateDTO {
        SupabaseAppStateDTO(
            owner: SupabaseAppOwnerDTO(
                id: ownerID,
                displayName: displayName,
                timezoneIdentifier: timezoneIdentifier,
                schemaVersion: state.schemaVersion,
                createdAt: ownerCreatedAt,
                updatedAt: ownerUpdatedAt
            ),
            weightGoal: weightGoalDTO(from: state.weightGoal, ownerID: ownerID),
            weightLogs: state.weightLogs.map { weightLogDTO(from: $0, ownerID: ownerID) },
            dailyHealthLogs: state.dailyHealthLogs.map { dailyHealthLogDTO(from: $0, ownerID: ownerID) },
            universityTasks: (state.criticalTasks + state.upcomingDeadlines).map { universityTaskDTO(from: $0, ownerID: ownerID) },
            moneyAccounts: state.moneyAccounts.map { moneyAccountDTO(from: $0, ownerID: ownerID) },
            moneyTransactions: state.moneyTransactions.map { moneyTransactionDTO(from: $0, ownerID: ownerID) },
            dailyOrderPlan: dailyOrderPlanDTO(from: state.dailyOrderPlan, ownerID: ownerID),
            dailyOrders: dailyOrderDTOs(from: state.dailyOrderPlan, ownerID: ownerID),
            dailyChecklistItems: dailyChecklistItemDTOs(from: state.dailyOrderPlan, ownerID: ownerID)
        )
    }

    static func makePersistedAppState(
        from snapshot: SupabaseAppStateDTO,
        waitingResponses: [SimpleListItem] = [],
        timeline: [SimpleListItem] = []
    ) -> PersistedAppState {
        let tasks = snapshot.universityTasks.map(academicTask(from:))
        let orderByID = Dictionary(uniqueKeysWithValues: snapshot.dailyOrders.map { ($0.id, $0) })
        let checklistItemsByOrderID = Dictionary(grouping: snapshot.dailyChecklistItems, by: \.orderID)

        let orders = snapshot.dailyOrders.map { orderDTO in
            dailyOrder(
                from: orderDTO,
                checklistItems: checklistItemsByOrderID[orderDTO.id] ?? []
            )
        }

        return PersistedAppState(
            schemaVersion: snapshot.owner.schemaVersion,
            weightGoal: weightGoal(from: snapshot.weightGoal),
            weightLogs: snapshot.weightLogs.map(weightLog(from:)).sorted { $0.date < $1.date },
            dailyHealthLogs: snapshot.dailyHealthLogs.map(dailyHealthLog(from:)).sorted { $0.date < $1.date },
            dailyOrderPlan: dailyOrderPlan(
                from: snapshot.dailyOrderPlan,
                orders: orders.sorted { lhs, rhs in
                    guard let lhsDTO = orderByID[lhs.id], let rhsDTO = orderByID[rhs.id] else {
                        return lhs.metadata.createdAt < rhs.metadata.createdAt
                    }

                    return lhsDTO.createdAt < rhsDTO.createdAt
                }
            ),
            criticalTasks: tasks.filter { $0.priority == .critical }.sorted(by: sortAcademicTasks),
            upcomingDeadlines: tasks.filter { $0.priority != .critical }.sorted(by: sortAcademicTasks),
            waitingResponses: waitingResponses,
            timeline: timeline,
            moneyAccounts: snapshot.moneyAccounts.map(moneyAccount(from:)).sorted { $0.name < $1.name },
            moneyTransactions: snapshot.moneyTransactions.map(moneyTransaction(from:)).sorted { $0.date > $1.date }
        )
    }
}

private extension SupabaseSyncMapper {
    static func weightGoalDTO(from goal: WeightGoal, ownerID: EntityID) -> SupabaseHealthWeightGoalDTO {
        SupabaseHealthWeightGoalDTO(
            id: goal.id,
            ownerID: ownerID,
            targetWeightKg: goal.targetWeightKg,
            startWeightKg: goal.startWeightKg,
            startDate: goal.startDate,
            targetDate: goal.targetDate,
            gymDayCalorieTarget: goal.gymDayCalorieTarget,
            restDayCalorieTarget: goal.restDayCalorieTarget,
            targetWorkoutsPerWeek: goal.targetWorkoutsPerWeek,
            idealGymWeekdays: goal.idealGymWeekdays,
            isActive: goal.isActive,
            notes: goal.notes,
            createdAt: goal.metadata.createdAt,
            updatedAt: goal.metadata.updatedAt,
            archivedAt: goal.metadata.archivedAt
        )
    }

    static func weightGoal(from dto: SupabaseHealthWeightGoalDTO) -> WeightGoal {
        WeightGoal(
            metadata: metadata(from: dto),
            targetWeightKg: dto.targetWeightKg,
            startWeightKg: dto.startWeightKg,
            startDate: dto.startDate,
            targetDate: dto.targetDate,
            gymDayCalorieTarget: dto.gymDayCalorieTarget,
            restDayCalorieTarget: dto.restDayCalorieTarget,
            targetWorkoutsPerWeek: dto.targetWorkoutsPerWeek,
            idealGymWeekdays: dto.idealGymWeekdays,
            isActive: dto.isActive,
            notes: dto.notes
        )
    }

    static func weightLogDTO(from log: WeightLog, ownerID: EntityID) -> SupabaseHealthWeightLogDTO {
        SupabaseHealthWeightLogDTO(
            id: log.id,
            ownerID: ownerID,
            logDate: log.date,
            weightKg: log.weightKg,
            source: log.source.source.rawValue,
            sourceImportedAt: log.source.importedAt,
            sourceExternalID: log.source.externalID,
            sourceDeviceName: log.source.deviceName,
            isLateEntry: log.lateEntry?.isLateEntry ?? false,
            originalEntryDate: log.lateEntry?.originalEntryDate,
            enteredAt: log.lateEntry?.enteredAt,
            lateEntryReason: log.lateEntry?.reason,
            notes: log.notes,
            createdAt: log.metadata.createdAt,
            updatedAt: log.metadata.updatedAt,
            archivedAt: log.metadata.archivedAt
        )
    }

    static func weightLog(from dto: SupabaseHealthWeightLogDTO) -> WeightLog {
        WeightLog(
            metadata: metadata(from: dto),
            date: dto.logDate,
            weightKg: dto.weightKg,
            source: healthSource(from: dto),
            lateEntry: lateEntry(
                isLateEntry: dto.isLateEntry,
                originalEntryDate: dto.originalEntryDate,
                enteredAt: dto.enteredAt,
                reason: dto.lateEntryReason
            ),
            notes: dto.notes
        )
    }

    static func dailyHealthLogDTO(from log: DailyHealthLog, ownerID: EntityID) -> SupabaseHealthDailyLogDTO {
        SupabaseHealthDailyLogDTO(
            id: log.id,
            ownerID: ownerID,
            logDate: log.date,
            totalCalories: log.totalCalories,
            gymAttended: log.gymAttended,
            workoutDurationMinutes: log.workoutDurationMinutes,
            workoutType: log.workoutType?.rawValue,
            sleepHours: log.sleepHours,
            sleepQuality: log.sleepQuality?.rawValue,
            source: log.source.source.rawValue,
            sourceImportedAt: log.source.importedAt,
            sourceExternalID: log.source.externalID,
            sourceDeviceName: log.source.deviceName,
            isLateEntry: log.lateEntry?.isLateEntry ?? false,
            originalEntryDate: log.lateEntry?.originalEntryDate,
            enteredAt: log.lateEntry?.enteredAt,
            lateEntryReason: log.lateEntry?.reason,
            notes: log.notes,
            createdAt: log.metadata.createdAt,
            updatedAt: log.metadata.updatedAt,
            archivedAt: log.metadata.archivedAt
        )
    }

    static func dailyHealthLog(from dto: SupabaseHealthDailyLogDTO) -> DailyHealthLog {
        DailyHealthLog(
            metadata: metadata(from: dto),
            date: dto.logDate,
            totalCalories: dto.totalCalories,
            gymAttended: dto.gymAttended,
            workoutDurationMinutes: dto.workoutDurationMinutes,
            workoutType: dto.workoutType.flatMap(WorkoutType.init(rawValue:)),
            sleepHours: dto.sleepHours,
            sleepQuality: dto.sleepQuality.flatMap(SleepQuality.init(rawValue:)),
            source: healthSource(from: dto),
            lateEntry: lateEntry(
                isLateEntry: dto.isLateEntry,
                originalEntryDate: dto.originalEntryDate,
                enteredAt: dto.enteredAt,
                reason: dto.lateEntryReason
            ),
            notes: dto.notes
        )
    }

    static func universityTaskDTO(from task: AcademicTask, ownerID: EntityID) -> SupabaseUniversityTaskDTO {
        SupabaseUniversityTaskDTO(
            id: task.id,
            ownerID: ownerID,
            courseID: task.courseID,
            title: task.title,
            category: task.category.rawValue,
            status: task.status.rawValue,
            priority: task.priority.rawValue,
            dueDate: task.dueDate,
            waitingSince: task.waitingSince,
            completedAt: task.completedAt,
            notes: task.notes,
            links: task.links,
            createdAt: task.metadata.createdAt,
            updatedAt: task.metadata.updatedAt,
            archivedAt: task.metadata.archivedAt
        )
    }

    static func academicTask(from dto: SupabaseUniversityTaskDTO) -> AcademicTask {
        AcademicTask(
            metadata: metadata(from: dto),
            courseID: dto.courseID,
            title: dto.title,
            category: AcademicTaskCategory(rawValue: dto.category) ?? .other,
            status: AcademicTaskStatus(rawValue: dto.status) ?? .pending,
            priority: AcademicTaskPriority(rawValue: dto.priority) ?? .medium,
            dueDate: dto.dueDate,
            waitingSince: dto.waitingSince,
            completedAt: dto.completedAt,
            notes: dto.notes,
            links: dto.links
        )
    }

    static func moneyAccountDTO(from account: MoneyAccount, ownerID: EntityID) -> SupabaseMoneyAccountDTO {
        SupabaseMoneyAccountDTO(
            id: account.id,
            ownerID: ownerID,
            name: account.name,
            currency: account.currency.rawValue,
            currentBalanceMinorUnits: account.currentBalance.minorUnits,
            kind: account.kind.rawValue,
            status: account.status.rawValue,
            color: account.color.rawValue,
            notes: account.notes,
            createdAt: account.metadata.createdAt,
            updatedAt: account.metadata.updatedAt,
            archivedAt: account.metadata.archivedAt
        )
    }

    static func moneyAccount(from dto: SupabaseMoneyAccountDTO) -> MoneyAccount {
        let currency = CurrencyCode(rawValue: dto.currency) ?? .ars

        return MoneyAccount(
            metadata: metadata(from: dto),
            name: dto.name,
            currency: currency,
            currentBalance: MoneyAmount(minorUnits: dto.currentBalanceMinorUnits, currency: currency),
            kind: MoneyAccountKind(rawValue: dto.kind) ?? .other,
            status: MoneyAccountStatus(rawValue: dto.status) ?? .active,
            color: MoneyAccountColor(rawValue: dto.color) ?? .money,
            notes: dto.notes
        )
    }

    static func moneyTransactionDTO(from transaction: MoneyTransaction, ownerID: EntityID) -> SupabaseMoneyTransactionDTO {
        let categoryParts = categoryParts(from: transaction.category)

        return SupabaseMoneyTransactionDTO(
            id: transaction.id,
            ownerID: ownerID,
            transactionDate: transaction.date,
            title: transaction.title,
            kind: transaction.kind.rawValue,
            amountMinorUnits: transaction.amount.minorUnits,
            amountCurrency: transaction.amount.currency.rawValue,
            fromAccountID: transaction.fromAccountID,
            toAccountID: transaction.toAccountID,
            categoryKind: categoryParts.kind,
            categoryLabel: categoryParts.label,
            balanceBeforeMinorUnits: transaction.balanceBefore?.minorUnits,
            balanceBeforeCurrency: transaction.balanceBefore?.currency.rawValue,
            balanceAfterMinorUnits: transaction.balanceAfter?.minorUnits,
            balanceAfterCurrency: transaction.balanceAfter?.currency.rawValue,
            notes: transaction.notes,
            createdAt: transaction.metadata.createdAt,
            updatedAt: transaction.metadata.updatedAt,
            archivedAt: transaction.metadata.archivedAt
        )
    }

    static func moneyTransaction(from dto: SupabaseMoneyTransactionDTO) -> MoneyTransaction {
        let amountCurrency = CurrencyCode(rawValue: dto.amountCurrency) ?? .ars

        return MoneyTransaction(
            metadata: metadata(from: dto),
            date: dto.transactionDate,
            title: dto.title,
            kind: MoneyTransactionKind(rawValue: dto.kind) ?? .expense,
            amount: MoneyAmount(minorUnits: dto.amountMinorUnits, currency: amountCurrency),
            fromAccountID: dto.fromAccountID,
            toAccountID: dto.toAccountID,
            category: transactionCategory(kind: dto.categoryKind, label: dto.categoryLabel),
            balanceBefore: moneyAmount(minorUnits: dto.balanceBeforeMinorUnits, currency: dto.balanceBeforeCurrency),
            balanceAfter: moneyAmount(minorUnits: dto.balanceAfterMinorUnits, currency: dto.balanceAfterCurrency),
            notes: dto.notes
        )
    }

    static func dailyOrderPlanDTO(from plan: AIGeneratedDailyOrderPlan, ownerID: EntityID) -> SupabaseDailyOrderPlanDTO {
        SupabaseDailyOrderPlanDTO(
            id: plan.id,
            ownerID: ownerID,
            planDate: plan.date,
            source: plan.source.rawValue,
            generatedAt: plan.generatedAt,
            promptVersion: plan.promptVersion,
            summary: plan.summary,
            createdAt: plan.metadata.createdAt,
            updatedAt: plan.metadata.updatedAt,
            archivedAt: plan.metadata.archivedAt
        )
    }

    static func dailyOrderPlan(from dto: SupabaseDailyOrderPlanDTO, orders: [DailyOrder]) -> AIGeneratedDailyOrderPlan {
        AIGeneratedDailyOrderPlan(
            metadata: metadata(from: dto),
            date: dto.planDate,
            source: DailyOrderSource(rawValue: dto.source) ?? .aiGenerated,
            generatedAt: dto.generatedAt,
            promptVersion: dto.promptVersion,
            summary: dto.summary,
            orders: orders
        )
    }

    static func dailyOrderDTOs(from plan: AIGeneratedDailyOrderPlan, ownerID: EntityID) -> [SupabaseDailyOrderDTO] {
        plan.orders.map { order in
            SupabaseDailyOrderDTO(
                id: order.id,
                ownerID: ownerID,
                planID: plan.id,
                title: order.title,
                area: order.area.rawValue,
                status: order.status.rawValue,
                priority: order.priority.rawValue,
                sourceEntityIDs: order.sourceEntityIDs,
                createdAt: order.metadata.createdAt,
                updatedAt: order.metadata.updatedAt,
                archivedAt: order.metadata.archivedAt
            )
        }
    }

    static func dailyOrder(from dto: SupabaseDailyOrderDTO, checklistItems: [SupabaseDailyChecklistItemDTO]) -> DailyOrder {
        DailyOrder(
            metadata: metadata(from: dto),
            title: dto.title,
            area: AppArea(rawValue: dto.area) ?? .dailyOrders,
            status: DailyOrderStatus(rawValue: dto.status) ?? .pending,
            priority: PriorityLevel(rawValue: dto.priority) ?? .medium,
            checklist: checklistItems.map(dailyChecklistItem(from:)),
            sourceEntityIDs: dto.sourceEntityIDs
        )
    }

    static func dailyChecklistItemDTOs(from plan: AIGeneratedDailyOrderPlan, ownerID: EntityID) -> [SupabaseDailyChecklistItemDTO] {
        plan.orders.flatMap { order in
            order.checklist.map { item in
                SupabaseDailyChecklistItemDTO(
                    id: item.id,
                    ownerID: ownerID,
                    orderID: order.id,
                    title: item.title,
                    kind: item.kind.rawValue,
                    area: item.area.rawValue,
                    status: item.status.rawValue,
                    priority: item.priority.rawValue,
                    sourceEntityID: item.sourceEntityID,
                    rationale: item.rationale,
                    createdAt: order.metadata.createdAt,
                    updatedAt: order.metadata.updatedAt,
                    archivedAt: order.metadata.archivedAt
                )
            }
        }
    }

    static func dailyChecklistItem(from dto: SupabaseDailyChecklistItemDTO) -> DailyChecklistItem {
        DailyChecklistItem(
            id: dto.id,
            title: dto.title,
            kind: DailyOrderItemKind(rawValue: dto.kind) ?? .task,
            area: AppArea(rawValue: dto.area) ?? .dailyOrders,
            status: DailyOrderStatus(rawValue: dto.status) ?? .pending,
            priority: PriorityLevel(rawValue: dto.priority) ?? .medium,
            sourceEntityID: dto.sourceEntityID,
            rationale: dto.rationale
        )
    }

    static func metadata(from dto: SupabaseHealthWeightGoalDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseHealthWeightLogDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseHealthDailyLogDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseUniversityTaskDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseMoneyAccountDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseMoneyTransactionDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseDailyOrderPlanDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func metadata(from dto: SupabaseDailyOrderDTO) -> BaseMetadata {
        BaseMetadata(id: dto.id, createdAt: dto.createdAt, updatedAt: dto.updatedAt, archivedAt: dto.archivedAt)
    }

    static func healthSource(from dto: SupabaseHealthWeightLogDTO) -> HealthSourceMetadata {
        HealthSourceMetadata(
            source: HealthEntrySource(rawValue: dto.source) ?? .manual,
            importedAt: dto.sourceImportedAt,
            externalID: dto.sourceExternalID,
            deviceName: dto.sourceDeviceName
        )
    }

    static func healthSource(from dto: SupabaseHealthDailyLogDTO) -> HealthSourceMetadata {
        HealthSourceMetadata(
            source: HealthEntrySource(rawValue: dto.source) ?? .manual,
            importedAt: dto.sourceImportedAt,
            externalID: dto.sourceExternalID,
            deviceName: dto.sourceDeviceName
        )
    }

    static func lateEntry(
        isLateEntry: Bool,
        originalEntryDate: Date?,
        enteredAt: Date?,
        reason: String?
    ) -> LateEntryMetadata? {
        guard isLateEntry, let originalEntryDate, let enteredAt else { return nil }

        return LateEntryMetadata(
            isLateEntry: true,
            originalEntryDate: originalEntryDate,
            enteredAt: enteredAt,
            reason: reason
        )
    }

    static func categoryParts(from category: MoneyTransactionCategory?) -> (kind: String?, label: String?) {
        switch category {
        case .income(let incomeCategory):
            return ("income", incomeCategory.rawValue)
        case .expense(let expenseCategory):
            return ("expense", expenseCategory.rawValue)
        case nil:
            return (nil, nil)
        }
    }

    static func transactionCategory(kind: String?, label: String?) -> MoneyTransactionCategory? {
        guard let kind, let label else { return nil }

        switch kind {
        case "income":
            return IncomeCategory(rawValue: label).map(MoneyTransactionCategory.income)
        case "expense":
            return ExpenseCategory(rawValue: label).map(MoneyTransactionCategory.expense)
        default:
            return nil
        }
    }

    static func moneyAmount(minorUnits: Int?, currency: String?) -> MoneyAmount? {
        guard let minorUnits, let currency, let currencyCode = CurrencyCode(rawValue: currency) else {
            return nil
        }

        return MoneyAmount(minorUnits: minorUnits, currency: currencyCode)
    }

    static func sortAcademicTasks(_ lhs: AcademicTask, _ rhs: AcademicTask) -> Bool {
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
