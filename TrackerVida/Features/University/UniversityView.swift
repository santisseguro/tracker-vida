import SwiftUI

struct UniversityView: View {
    var body: some View {
        ScreenScaffold(
            title: "Study Cockpit",
            subtitle: "Critical tasks, upcoming deadlines, replies, and timeline preview."
        ) {
            AppCard(tint: AppTheme.Colors.university) {
                HStack {
                    StatusPill(text: "Focus block", tint: AppTheme.Colors.university)
                    Spacer()
                    Text("\(MockData.criticalTasks.count) critical")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.university)
                }

                Text("Clear the urgent lane first.")
                    .font(.title.weight(.bold))
                ProgressView(value: 0.36)
                    .tint(AppTheme.Colors.university)
            }

            AppCard {
                Text("Academic board")
                    .font(.headline.weight(.bold))

                ForEach(MockData.criticalTasks) { task in
                    InfoRow(title: task.title, detail: task.type.rawValue, value: task.priority.rawValue.capitalized, symbol: "exclamationmark.circle.fill", tint: AppTheme.Colors.university)
                }

                Divider()

                ForEach(MockData.upcomingDeadlines) { task in
                    InfoRow(title: task.title, detail: task.type.rawValue, value: task.dueDate?.formatted(date: .abbreviated, time: .omitted), symbol: "calendar", tint: AppTheme.Colors.primary)
                }
            }

            AppCard(tint: AppTheme.Colors.warning, compact: true) {
                HStack {
                    Text("Waiting for response")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "\(MockData.waitingResponses.count) open", tint: AppTheme.Colors.warning)
                }

                ForEach(MockData.waitingResponses) { item in
                    InfoRow(title: item.title, detail: item.detail, value: item.value, symbol: "envelope.fill", tint: AppTheme.Colors.warning)
                }
            }

            AppCard(tint: AppTheme.Colors.ai) {
                Text("Timeline preview")
                    .font(.headline.weight(.bold))
                ForEach(MockData.timeline) { item in
                    InfoRow(title: item.title, detail: item.detail, value: item.value, symbol: "clock.fill", tint: AppTheme.Colors.ai)
                }
            }
        }
    }
}
