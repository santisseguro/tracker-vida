import Charts
import SwiftUI

struct GymHealthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var healthEntryDraft: HealthEntryFormDraft?

    private var state: GymHealthViewState { store.gymHealthState }

    var body: some View {
        ScreenScaffold(
            title: "Body Dashboard",
            subtitle: "Weight, calories, gym attendance, sleep, and today's local order."
        ) {
            AICommandBar(
                context: .gymHealth,
                latestCommand: store.latestCapturedAICommand(for: .gymHealth)
            ) { command in
                store.captureAICommand(command, context: .gymHealth)
                return true
            }

            AppCard(tint: AppTheme.Colors.health) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current weight")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(state.latestWeight?.weightKg.formatted(.number.precision(.fractionLength(1))) ?? "--") kg")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    StatusPill(text: "Manual", tint: AppTheme.Colors.health)
                }

                HStack {
                    Text("Goal \(state.weightGoal.targetWeightKg.formatted(.number.precision(.fractionLength(0)))) kg")
                    Spacer()
                    Text(weightRemainingText)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ProgressView(value: 0.58)
                    .tint(AppTheme.Colors.health)
            }

            AppCard(compact: true) {
                Text("Log today")
                    .font(.headline.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(HealthEntryMode.allCases) { mode in
                        HealthActionButton(mode: mode) {
                            presentHealthEntryForm(mode)
                        }
                    }
                }
            }

            AppCard {
                HStack {
                    Text("Monthly weight trend")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Local", tint: AppTheme.Colors.primary)
                }

                MonthlyWeightTrendChart(weightLogs: store.weightLogs, referenceDate: store.currentDate)
            }

            AppCard {
                Text("Week at a glance")
                    .font(.headline.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    MetricTile(title: "Calories today", value: "\(state.todayHealth?.totalCalories ?? 0)", detail: "of 2,300", tint: AppTheme.Colors.warning, progress: Double(state.todayHealth?.totalCalories ?? 0) / 2300)
                    MetricTile(title: "Weekly calories", value: "\(state.weeklyCalories.formatted())", detail: "last logs", tint: AppTheme.Colors.primary, progress: Double(state.weeklyCalories) / 15000)
                    MetricTile(title: "Gym progress", value: "\(state.gymAttendance)/5", detail: "weekly", tint: AppTheme.Colors.health, progress: Double(state.gymAttendance) / 5)
                    MetricTile(title: "Sleep average", value: "\(state.averageSleepHours.formatted(.number.precision(.fractionLength(1))))h", detail: "\(state.todayHealth?.sleepQuality?.rawValue ?? "Good") today", tint: AppTheme.Colors.ai, progress: state.averageSleepHours / 8)
                }
            }

            AppCard(tint: AppTheme.Colors.ai) {
                HStack {
                    Text("AI order checklist")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Local", tint: AppTheme.Colors.ai)
                }

                ForEach(state.dailyOrderPlan.orders.first?.checklist ?? []) { item in
                    ChecklistActionRow(item: item) {
                        store.toggleDailyChecklistItem(item.id)
                    }
                }
            }
        }
        .sheet(item: $healthEntryDraft) { draft in
            HealthEntryFormView(draft: draft)
                .environmentObject(store)
        }
    }

    private func presentHealthEntryForm(_ mode: HealthEntryMode) {
        let date = store.currentDate
        healthEntryDraft = HealthEntryFormDraft(
            mode: mode,
            date: date,
            weightLog: store.weightLog(on: date),
            healthLog: store.dailyHealthLog(on: date)
        )
    }

    private var weightRemainingText: String {
        guard let latestWeight = state.latestWeight else { return "-- kg remaining" }

        let remainingKg = state.weightGoal.targetWeightKg - latestWeight.weightKg
        return "\(remainingKg.formatted(.number.precision(.fractionLength(1)))) kg remaining"
    }
}

private struct MonthlyWeightTrendChart: View {
    var weightLogs: [WeightLog]
    var referenceDate: Date

    private var points: [MonthlyWeightTrendPoint] {
        MonthlyWeightTrendCalculator.points(weightLogs: weightLogs, referenceDate: referenceDate)
    }

    var body: some View {
        if points.count >= 2 {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weightKg)
                )
                .foregroundStyle(AppTheme.Colors.primary)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weightKg)
                )
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .frame(height: 160)
            .chartYScale(domain: yAxisDomain)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text("\(weight.formatted(.number.precision(.fractionLength(1))))")
                        }
                    }
                }
            }

            HStack {
                Text("\(points.first?.weightKg.formatted(.number.precision(.fractionLength(1))) ?? "--") kg")
                Spacer()
                Text(weightDeltaText)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.Colors.primary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Not enough weight data yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Log weight at least twice this month to see variation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(AppTheme.Colors.elevatedCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        let weights = points.map(\.weightKg)
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 0...1
        }

        return (minWeight - 1)...(maxWeight + 1)
    }

    private var weightDeltaText: String {
        guard let first = points.first?.weightKg, let last = points.last?.weightKg else { return "-- kg" }

        let delta = last - first
        let prefix = delta > 0 ? "+" : ""
        return "\(prefix)\(delta.formatted(.number.precision(.fractionLength(1)))) kg"
    }
}

private struct MonthlyWeightTrendPoint: Identifiable {
    var date: Date
    var weightKg: Double

    var id: String {
        "\(date.timeIntervalSince1970)-\(weightKg)"
    }
}

private enum MonthlyWeightTrendCalculator {
    static func points(weightLogs: [WeightLog], referenceDate: Date, calendar: Calendar = .current) -> [MonthlyWeightTrendPoint] {
        let endDate = calendar.startOfDay(for: referenceDate)
        let startDate = calendar.date(byAdding: .day, value: -29, to: endDate) ?? endDate

        return weightLogs
            .filter { $0.date >= startDate && $0.date <= referenceDate }
            .sorted { $0.date < $1.date }
            .map { MonthlyWeightTrendPoint(date: $0.date, weightKg: $0.weightKg) }
    }
}

private enum HealthEntryMode: String, CaseIterable, Identifiable {
    case weight
    case calories
    case gym
    case sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight:
            return "Weight"
        case .calories:
            return "Calories"
        case .gym:
            return "Gym"
        case .sleep:
            return "Sleep"
        }
    }

    var navigationTitle: String {
        switch self {
        case .weight:
            return "Log weight"
        case .calories:
            return "Log calories"
        case .gym:
            return "Log gym"
        case .sleep:
            return "Log sleep"
        }
    }

    var symbol: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .calories:
            return "flame.fill"
        case .gym:
            return "figure.strengthtraining.traditional"
        case .sleep:
            return "moon.zzz.fill"
        }
    }

    var tint: Color {
        switch self {
        case .weight:
            return AppTheme.Colors.primary
        case .calories:
            return AppTheme.Colors.warning
        case .gym:
            return AppTheme.Colors.health
        case .sleep:
            return AppTheme.Colors.ai
        }
    }
}

private struct HealthActionButton: View {
    var mode: HealthEntryMode
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(mode.tint)
                    .frame(width: 34, height: 34)
                    .background(mode.tint.opacity(0.14), in: Circle())

                Text(mode.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(AppTheme.Colors.elevatedCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.navigationTitle)
    }
}

private struct ChecklistActionRow: View {
    var item: DailyChecklistItem
    var action: () -> Void

    private var isComplete: Bool {
        item.status == .done || item.status == .skipped
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: action) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isComplete ? AppTheme.Colors.health : AppTheme.Colors.ai)
                    .frame(width: 34, height: 34)
                    .background((isComplete ? AppTheme.Colors.health : AppTheme.Colors.ai).opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isComplete ? "Mark checklist item pending" : "Mark checklist item done")

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isComplete ? .secondary : .primary)
                    .strikethrough(isComplete, color: .secondary)
                    .lineSpacing(2)

                Text(item.priority.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            StatusPill(text: isComplete ? "Done" : "Pending", tint: isComplete ? AppTheme.Colors.health : AppTheme.Colors.ai)
        }
        .padding(12)
        .background(AppTheme.Colors.elevatedCard.opacity(isComplete ? 0.58 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder((isComplete ? AppTheme.Colors.health : AppTheme.Colors.ai).opacity(isComplete ? 0.22 : 0.08), lineWidth: 1)
        )
    }
}

private struct HealthEntryFormDraft: Identifiable {
    let id = UUID()
    var mode: HealthEntryMode
    var date: Date
    var weightText: String
    var caloriesText: String
    var gymAttended: Bool
    var durationText: String
    var workoutType: WorkoutType
    var sleepHoursText: String
    var sleepQuality: SleepQuality

    init(mode: HealthEntryMode, date: Date, weightLog: WeightLog?, healthLog: DailyHealthLog?) {
        self.mode = mode
        self.date = date
        weightText = weightLog?.weightKg.formatted(.number.precision(.fractionLength(1))) ?? ""
        caloriesText = healthLog?.totalCalories.map(String.init) ?? ""
        gymAttended = healthLog?.gymAttended ?? false
        durationText = healthLog?.workoutDurationMinutes.map(String.init) ?? ""
        workoutType = healthLog?.workoutType ?? .push
        sleepHoursText = healthLog?.sleepHours?.formatted(.number.precision(.fractionLength(1))) ?? ""
        sleepQuality = healthLog?.sleepQuality ?? .good
    }

    var weightKg: Double? {
        Double(decimalText: weightText)
    }

    var calories: Int? {
        Int(trimmedText: caloriesText)
    }

    var durationMinutes: Int? {
        Int(trimmedText: durationText)
    }

    var sleepHours: Double? {
        Double(decimalText: sleepHoursText)
    }
}

private struct HealthEntryFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HealthEntryFormDraft

    init(draft: HealthEntryFormDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Entry date", selection: $draft.date, displayedComponents: .date)
                }

                if draft.mode == .weight {
                    Section("Weight") {
                        TextField("Weight kg", text: $draft.weightText)
                            .keyboardType(.decimalPad)
                    }
                }

                if draft.mode == .calories {
                    Section("Calories") {
                        TextField("Total calories", text: $draft.caloriesText)
                            .keyboardType(.numberPad)
                    }
                }

                if draft.mode == .gym {
                    Section("Gym") {
                        Toggle("Went to gym", isOn: $draft.gymAttended)

                        if draft.gymAttended {
                            TextField("Duration minutes", text: $draft.durationText)
                                .keyboardType(.numberPad)

                            Picker("Workout type", selection: $draft.workoutType) {
                                ForEach(WorkoutType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        }
                    }
                }

                if draft.mode == .sleep {
                    Section("Sleep") {
                        TextField("Hours slept", text: $draft.sleepHoursText)
                            .keyboardType(.decimalPad)

                        Picker("Quality", selection: $draft.sleepQuality) {
                            ForEach(SleepQuality.allCases) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                    }
                }
            }
            .navigationTitle(draft.mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
            .onChange(of: draft.date) { _, newDate in
                reloadDraft(for: newDate)
            }
        }
    }

    private func reloadDraft(for date: Date) {
        draft = HealthEntryFormDraft(
            mode: draft.mode,
            date: date,
            weightLog: store.weightLog(on: date),
            healthLog: store.dailyHealthLog(on: date)
        )
    }

    private func save() {
        if draft.mode == .weight, let weightKg = draft.weightKg {
            store.upsertWeightLog(date: draft.date, weightKg: weightKg)
            return
        }

        store.upsertDailyHealthLog(
            date: draft.date,
            totalCalories: draft.calories,
            gymAttended: draft.gymAttended,
            workoutDurationMinutes: draft.durationMinutes,
            workoutType: draft.gymAttended ? draft.workoutType : nil,
            sleepHours: draft.sleepHours,
            sleepQuality: draft.sleepHours == nil ? nil : draft.sleepQuality
        )
    }
}

private extension Double {
    init?(decimalText: String) {
        let normalized = decimalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !normalized.isEmpty else { return nil }
        self.init(normalized)
    }
}

private extension Int {
    init?(trimmedText: String) {
        let trimmed = trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }
        self.init(trimmed)
    }
}
