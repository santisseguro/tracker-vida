import Foundation

enum AIAssistantContextBuilder {
    @MainActor
    static func context(for section: AICommandContext, from store: AppStore, generatedAt: Date? = nil) -> AISectionContext {
        switch section {
        case .dashboard:
            return dashboardContext(from: store, generatedAt: generatedAt)
        case .gymHealth:
            return gymHealthContext(from: store, generatedAt: generatedAt)
        case .university:
            return universityContext(from: store, generatedAt: generatedAt)
        case .money:
            return moneyContext(from: store, generatedAt: generatedAt)
        }
    }

    @MainActor
    static func dashboardContext(from store: AppStore, generatedAt: Date? = nil) -> AISectionContext {
        let state = store.dashboardState
        let orders = store.dailyOrdersState

        return AISectionContext(
            section: .dashboard,
            generatedAt: generatedAt ?? store.currentDate,
            dashboard: AIDashboardAssistantContext(
                latestWeightKg: state.latestWeight?.weightKg,
                todayCalories: state.todayHealth?.totalCalories,
                weeklyGymCount: state.weeklyGymCount,
                dailyOrderTitle: state.dailyOrderPlan.orders.first?.title,
                dailyOrderSummary: state.dailyOrderPlan.summary,
                dailyOrderCompletionRatio: state.dailyOrderPlan.completionRatio,
                dailyOrderCompletedItems: orders.completedItems,
                dailyOrderTotalItems: orders.totalItems,
                activeCriticalTaskCount: state.activeCriticalTasks.count,
                upcomingDeadlineCount: state.upcomingDeadlines.count,
                moneyTotals: moneyTotalsContext(from: state.moneyTotals)
            )
        )
    }

    @MainActor
    static func gymHealthContext(from store: AppStore, generatedAt: Date? = nil) -> AISectionContext {
        let state = store.gymHealthState
        let progress = state.progress

        return AISectionContext(
            section: .gymHealth,
            generatedAt: generatedAt ?? store.currentDate,
            gymHealth: AIGymHealthAssistantContext(
                currentWeightKg: progress.currentWeightKg,
                sevenDayAverageWeightKg: progress.sevenDayAverageWeightKg,
                targetWeightKg: state.weightGoal.targetWeightKg,
                weightRemainingKg: progress.weightRemainingKg,
                todayCalories: state.todayHealth?.totalCalories,
                dailyCalorieTarget: progress.dailyCalorieTarget,
                dailyCalorieDelta: progress.dailyCalorieDelta,
                weeklyCalorieTarget: progress.weeklyCalorieTarget,
                weeklyCaloriesConsumed: progress.weeklyCaloriesConsumed,
                weeklyCalorieDelta: progress.weeklyCalorieDelta,
                estimatedWeightImpactKg: progress.estimatedWeightImpactKg,
                estimatedTargetDate: progress.estimatedTargetDate,
                completedWorkouts: progress.completedWorkouts,
                targetWorkouts: progress.targetWorkouts,
                trackStatus: progress.trackStatus,
                averageSleepHours: state.averageSleepHours,
                dailyOrderTitle: state.dailyOrderPlan.orders.first?.title,
                dailyOrderSummary: state.dailyOrderPlan.summary,
                checklistItems: state.dailyOrderPlan.orders
                    .flatMap(\.checklist)
                    .map(checklistItemContext)
            )
        )
    }

    @MainActor
    static func universityContext(from store: AppStore, generatedAt: Date? = nil) -> AISectionContext {
        let state = store.universityState

        return AISectionContext(
            section: .university,
            generatedAt: generatedAt ?? store.currentDate,
            university: AIUniversityAssistantContext(
                activeCriticalTasks: state.activeCriticalTasks.map(academicTaskContext),
                upcomingDeadlines: state.upcomingDeadlines.map(academicTaskContext),
                waitingResponses: state.waitingResponses.map(listItemContext),
                timeline: state.timeline.map(listItemContext),
                classes: state.classes.map(universityClassContext),
                todayClasses: state.todayClasses.map(scheduledClassContext),
                upcomingClassesThisWeek: state.upcomingClassesThisWeek.map(scheduledClassContext)
            )
        )
    }

    @MainActor
    static func moneyContext(from store: AppStore, generatedAt: Date? = nil) -> AISectionContext {
        let state = store.moneyState

        return AISectionContext(
            section: .money,
            generatedAt: generatedAt ?? store.currentDate,
            money: AIMoneyAssistantContext(
                accounts: state.activeAccounts.map(moneyAccountContext),
                accountBalances: state.accountBalances.map(listItemContext),
                recentTransactions: state.transactions.prefix(12).map(moneyTransactionContext),
                totals: moneyTotalsContext(from: state.totals)
            )
        )
    }

    private static func checklistItemContext(from item: DailyChecklistItem) -> AIChecklistItemContext {
        AIChecklistItemContext(
            id: item.id,
            title: item.title,
            status: item.status,
            priority: item.priority,
            area: item.area
        )
    }

    private static func academicTaskContext(from task: AcademicTask) -> AIAcademicTaskContext {
        AIAcademicTaskContext(
            id: task.id,
            title: task.title,
            category: task.category,
            status: task.status,
            priority: task.priority,
            dueDate: task.dueDate,
            waitingSince: task.waitingSince,
            notes: task.notes
        )
    }

    private static func listItemContext(from item: SimpleListItem) -> AIListItemContext {
        AIListItemContext(
            id: item.id,
            title: item.title,
            detail: item.detail,
            value: item.value
        )
    }

    private static func universityClassContext(from universityClass: UniversityClass) -> AIUniversityClassContext {
        AIUniversityClassContext(
            id: universityClass.id,
            name: universityClass.name,
            shortName: universityClass.shortName,
            instructor: universityClass.instructor,
            location: universityClass.location,
            color: universityClass.color
        )
    }

    private static func scheduledClassContext(from scheduledClass: UniversityScheduledClass) -> AIUniversityScheduledClassContext {
        AIUniversityScheduledClassContext(
            id: scheduledClass.id,
            classID: scheduledClass.universityClass.id,
            className: scheduledClass.universityClass.name,
            weekday: scheduledClass.session.weekday,
            occurrenceDate: scheduledClass.occurrenceDate,
            startMinuteOfDay: scheduledClass.session.startMinuteOfDay,
            endMinuteOfDay: scheduledClass.session.endMinuteOfDay,
            location: scheduledClass.location
        )
    }

    private static func moneyAccountContext(from account: MoneyAccount) -> AIMoneyAccountContext {
        AIMoneyAccountContext(
            id: account.id,
            name: account.name,
            currency: account.currency,
            balanceMinorUnits: account.currentBalance.minorUnits,
            kind: account.kind,
            color: account.color
        )
    }

    private static func moneyTransactionContext(from transaction: MoneyTransaction) -> AIMoneyTransactionContext {
        AIMoneyTransactionContext(
            id: transaction.id,
            date: transaction.date,
            title: transaction.title,
            kind: transaction.kind,
            amount: transaction.amount,
            fromAccountID: transaction.fromAccountID,
            toAccountID: transaction.toAccountID,
            categoryLabel: transaction.category?.label,
            notes: transaction.notes
        )
    }

    private static func moneyTotalsContext(from totals: MoneyTotals) -> AIMoneyTotalsContext {
        AIMoneyTotalsContext(
            arsMinorUnits: totals.arsMinorUnits,
            usdtMinorUnits: totals.usdtMinorUnits,
            arsEquivalentMinorUnits: totals.arsEquivalentMinorUnits,
            mockUSDTToARSRate: totals.mockUSDTToARSRate
        )
    }
}

