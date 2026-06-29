import SwiftUI

struct GymHealthView: View {
    private var latestWeight: WeightLog? { MockData.weightLogs.latest }
    private var todayHealth: DailyHealthLog? { MockData.dailyHealthLogs.last }

    var body: some View {
        ScreenScaffold(
            title: "Body Dashboard",
            subtitle: "Weight, calories, gym attendance, sleep, and today's mock order."
        ) {
            AppCard(tint: AppTheme.Colors.health) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current weight")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(latestWeight?.weightKg.formatted(.number.precision(.fractionLength(1))) ?? "--") kg")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    StatusPill(text: "Manual", tint: AppTheme.Colors.health)
                }

                HStack {
                    Text("Goal \(MockData.weightGoal.targetWeightKg.formatted(.number.precision(.fractionLength(0)))) kg")
                    Spacer()
                    Text("-4.0 kg remaining")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ProgressView(value: 0.58)
                    .tint(AppTheme.Colors.health)
            }

            AppCard {
                Text("Week at a glance")
                    .font(.headline.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    MetricTile(title: "Calories today", value: "\(todayHealth?.totalCalories ?? 0)", detail: "of 2,300", tint: AppTheme.Colors.warning, progress: Double(todayHealth?.totalCalories ?? 0) / 2300)
                    MetricTile(title: "Weekly calories", value: "\(MockData.dailyHealthLogs.totalCalories.formatted())", detail: "last logs", tint: AppTheme.Colors.primary, progress: Double(MockData.dailyHealthLogs.totalCalories) / 15000)
                    MetricTile(title: "Gym progress", value: "\(MockData.dailyHealthLogs.gymAttendanceCount)/5", detail: "weekly", tint: AppTheme.Colors.health, progress: Double(MockData.dailyHealthLogs.gymAttendanceCount) / 5)
                    MetricTile(title: "Sleep average", value: "\(MockData.dailyHealthLogs.averageSleepHours.formatted(.number.precision(.fractionLength(1))))h", detail: "\(todayHealth?.sleepQuality?.rawValue ?? "Good") today", tint: AppTheme.Colors.ai, progress: MockData.dailyHealthLogs.averageSleepHours / 8)
                }
            }

            AppCard(tint: AppTheme.Colors.ai) {
                HStack {
                    Text("AI order checklist")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Mock", tint: AppTheme.Colors.ai)
                }

                ForEach(MockData.dailyOrderPlan.orders.first?.checklist ?? []) { item in
                    InfoRow(title: item.title, detail: item.priority.rawValue.capitalized, value: item.status.rawValue, symbol: "checklist", tint: AppTheme.Colors.ai)
                }
            }
        }
    }
}
