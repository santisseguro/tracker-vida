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
            AppCard(tint: AppTheme.Colors.ai) {
                HStack(alignment: .top) {
                    StatusPill(text: "Mock AI order", tint: AppTheme.Colors.ai)
                    Spacer()
                    Text("\(dailyOrdersState.completedItems)/\(dailyOrdersState.totalItems)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.ai)
                }

                Text("Move with intention.")
                    .font(.title.weight(.bold))
                Text(state.dailyOrderPlan.summary ?? "Static daily order preview.")
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
                        value: "$501K",
                        detail: "ARS + USDT",
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
                    InfoRow(
                        title: task.title,
                        detail: task.category.rawValue,
                        value: task.priority.rawValue,
                        symbol: "exclamationmark.circle.fill",
                        tint: AppTheme.Colors.university
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.markAcademicTaskCompleted(task.id)
                    }
                }

                Divider()

                ForEach(state.upcomingDeadlines.prefix(2)) { task in
                    InfoRow(
                        title: task.title,
                        detail: task.category.rawValue,
                        value: task.dueDate?.formatted(date: .abbreviated, time: .omitted),
                        symbol: "calendar",
                        tint: AppTheme.Colors.primary
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.markAcademicTaskCompleted(task.id)
                    }
                }
            }

            AppCard(compact: true) {
                Text("Money snapshot")
                    .font(.headline.weight(.bold))
                ForEach(state.accountBalances) { balance in
                    InfoRow(title: balance.title, detail: balance.detail, value: balance.value, symbol: "wallet.pass.fill", tint: AppTheme.Colors.money)
                }
            }
        }
    }
}
