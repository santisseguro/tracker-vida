import SwiftUI

struct DashboardView: View {
    private var latestWeight: WeightLog? { MockData.weightLogs.latest }
    private var todayHealth: DailyHealthLog? { MockData.dailyHealthLogs.last }

    var body: some View {
        ScreenScaffold(
            title: "Today",
            subtitle: "Your personal command center for health, study, and money."
        ) {
            AppCard(tint: AppTheme.Colors.ai) {
                HStack(alignment: .top) {
                    StatusPill(text: "Mock AI order", tint: AppTheme.Colors.ai)
                    Spacer()
                    Text("\(completedDailyItems)/\(totalDailyItems)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.ai)
                }

                Text("Move with intention.")
                    .font(.title.weight(.bold))
                Text(MockData.dailyOrderPlan.summary ?? "Static daily order preview.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)

                ProgressView(value: MockData.dailyOrderPlan.completionRatio)
                    .tint(AppTheme.Colors.ai)
            }

            AppCard {
                Text("Daily signals")
                    .font(.headline.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    MetricTile(
                        title: "Gym",
                        value: "\(MockData.dailyHealthLogs.gymAttendanceCount)/5",
                        detail: "weekly target",
                        tint: AppTheme.Colors.health,
                        progress: Double(MockData.dailyHealthLogs.gymAttendanceCount) / 5
                    )
                    MetricTile(
                        title: "Weight",
                        value: "\(latestWeight?.weightKg.formatted(.number.precision(.fractionLength(1))) ?? "--") kg",
                        detail: "goal \(MockData.weightGoal.targetWeightKg.formatted(.number.precision(.fractionLength(0)))) kg",
                        tint: AppTheme.Colors.primary,
                        progress: 0.58
                    )
                    MetricTile(
                        title: "Calories",
                        value: "\(todayHealth?.totalCalories ?? 0)",
                        detail: "today",
                        tint: AppTheme.Colors.warning,
                        progress: Double(todayHealth?.totalCalories ?? 0) / 2300
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
                    StatusPill(text: "2 critical", tint: AppTheme.Colors.university)
                }

                ForEach(MockData.criticalTasks) { task in
                    InfoRow(
                        title: task.title,
                        detail: task.type.rawValue,
                        value: task.priority.rawValue.capitalized,
                        symbol: "exclamationmark.circle.fill",
                        tint: AppTheme.Colors.university
                    )
                }

                Divider()

                ForEach(MockData.upcomingDeadlines.prefix(2)) { task in
                    InfoRow(
                        title: task.title,
                        detail: task.type.rawValue,
                        value: task.dueDate?.formatted(date: .abbreviated, time: .omitted),
                        symbol: "calendar",
                        tint: AppTheme.Colors.primary
                    )
                }
            }

            AppCard(compact: true) {
                Text("Money snapshot")
                    .font(.headline.weight(.bold))
                ForEach(MockData.accountBalances) { balance in
                    InfoRow(title: balance.title, detail: balance.detail, value: balance.value, symbol: "wallet.pass.fill", tint: AppTheme.Colors.money)
                }
            }
        }
    }

    private var totalDailyItems: Int {
        MockData.dailyOrderPlan.orders.flatMap(\.checklist).count
    }

    private var completedDailyItems: Int {
        MockData.dailyOrderPlan.orders
            .flatMap(\.checklist)
            .filter { $0.status == .done || $0.status == .skipped }
            .count
    }
}
