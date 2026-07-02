import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore

    private var state: DashboardViewState { store.dashboardState }
    private var dailyOrdersState: DailyOrdersViewState { store.dailyOrdersState }

    var body: some View {
        ScreenScaffold(
            title: "Today",
            subtitle: "Your personal command center for health, study, and money."
        ) {
            AICommandBar(
                context: .dashboard,
                latestCommand: store.latestCapturedAICommand(for: .dashboard)
            ) { command in
                store.captureAICommand(command, context: .dashboard)
                return true
            }

            AppCard(tint: AppTheme.Colors.ai) {
                HStack(alignment: .top) {
                    StatusPill(text: "Rule-based order", tint: AppTheme.Colors.ai)
                    Spacer()
                    Text("\(dailyOrdersState.completedItems)/\(dailyOrdersState.totalItems)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.ai)
                }

                Text(state.dailyOrderPlan.orders.first?.title ?? "Hold the plan today.")
                    .font(.title.weight(.bold))
                Text(state.dailyOrderPlan.summary ?? "Local rule-based daily order.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)

                ProgressView(value: state.dailyOrderPlan.completionRatio)
                    .tint(AppTheme.Colors.ai)
            }

            AppCard {
                Text("Daily signals")
                    .font(.headline.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    MetricTile(
                        title: "Gym",
                        value: "\(state.weeklyGymCount)/5",
                        detail: "weekly target",
                        tint: AppTheme.Colors.health,
                        progress: Double(state.weeklyGymCount) / 5
                    )
                    MetricTile(
                        title: "Weight",
                        value: "\(state.latestWeight?.weightKg.formatted(.number.precision(.fractionLength(1))) ?? "--") kg",
                        detail: "goal \(state.weightGoal.targetWeightKg.formatted(.number.precision(.fractionLength(0)))) kg",
                        tint: AppTheme.Colors.primary,
                        progress: 0.58
                    )
                    MetricTile(
                        title: "Calories",
                        value: "\(state.todayHealth?.totalCalories ?? 0)",
                        detail: "today",
                        tint: AppTheme.Colors.warning,
                        progress: Double(state.todayHealth?.totalCalories ?? 0) / 2300
                    )
                    MetricTile(
                        title: "Money",
                        value: state.moneyTotals.usdtLabeledDisplay,
                        detail: state.moneyTotals.arsEquivalentDisplay,
                        tint: AppTheme.Colors.money,
                        progress: nil
                    )
                }
            }

            AppCard {
                HStack {
                    Text("Focus stack")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "\(state.activeCriticalTasks.count) critical", tint: AppTheme.Colors.university)
                }

                ForEach(state.activeCriticalTasks) { task in
                    DashboardTaskActionRow(
                        title: task.title,
                        detail: task.category.rawValue,
                        value: task.priority.rawValue,
                        symbol: "exclamationmark.circle.fill",
                        tint: AppTheme.Colors.university
                    ) {
                        store.markAcademicTaskCompleted(task.id)
                    }
                }

                Divider()

                ForEach(state.upcomingDeadlines.prefix(2)) { task in
                    DashboardTaskActionRow(
                        title: task.title,
                        detail: task.category.rawValue,
                        value: task.dueDate?.formatted(date: .abbreviated, time: .omitted),
                        symbol: "calendar",
                        tint: AppTheme.Colors.primary
                    ) {
                        store.markAcademicTaskCompleted(task.id)
                    }
                }
            }

            AppCard(compact: true) {
                HStack {
                    Text("Money snapshot")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Monthly", tint: AppTheme.Colors.money)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.moneyTotals.arsEquivalentDisplay)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(state.moneyTotals.usdtLabeledDisplay)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                MoneyBalanceTrendChart(
                    accounts: store.moneyState.activeAccounts,
                    transactions: store.moneyState.transactions,
                    referenceDate: store.currentDate,
                    usdtToARSRate: store.moneyState.totals.mockUSDTToARSRate,
                    range: .monthly,
                    compact: true
                )

                ForEach(store.moneyState.activeAccounts) { account in
                    DashboardMoneyAccountRow(account: account)
                }
            }
        }
    }
}

private struct DashboardMoneyAccountRow: View {
    var account: MoneyAccount

    var body: some View {
        InfoRow(
            title: account.name,
            detail: account.currency.rawValue,
            value: formattedBalance,
            symbol: "wallet.pass.fill",
            tint: account.color.tint
        )
    }

    private var formattedBalance: String {
        switch account.currentBalance.currency {
        case .ars:
            return "$\(account.currentBalance.minorUnits.formatted())"
        case .usdt:
            return "\(account.currentBalance.minorUnits.formatted())"
        }
    }
}

private struct DashboardTaskActionRow: View {
    var title: String
    var detail: String?
    var value: String?
    var symbol: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let value {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Button(action: action) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.health)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(title) completed")
        }
        .padding(.vertical, 4)
    }
}
