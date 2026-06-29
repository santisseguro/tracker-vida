import SwiftUI

struct GymHealthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var healthEntryDraft: HealthEntryFormDraft?

    private var state: GymHealthViewState { store.gymHealthState }

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
            .contentShape(Rectangle())
            .onTapGesture {
                presentHealthEntryForm()
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
            .contentShape(Rectangle())
            .onTapGesture {
                presentHealthEntryForm()
            }

            AppCard(tint: AppTheme.Colors.ai) {
                HStack {
                    Text("AI order checklist")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Mock", tint: AppTheme.Colors.ai)
                }

                ForEach(state.dailyOrderPlan.orders.first?.checklist ?? []) { item in
                    InfoRow(title: item.title, detail: item.priority.rawValue.capitalized, value: item.status.rawValue, symbol: "checklist", tint: AppTheme.Colors.ai)
                        .contentShape(Rectangle())
                        .onTapGesture {
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

    private func presentHealthEntryForm() {
        let date = store.currentDate
        healthEntryDraft = HealthEntryFormDraft(
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

private struct HealthEntryFormDraft: Identifiable {
    let id = UUID()
    var date: Date
    var weightText: String
    var caloriesText: String
    var gymAttended: Bool
    var durationText: String
    var workoutType: WorkoutType
    var sleepHoursText: String
    var sleepQuality: SleepQuality

    init(date: Date, weightLog: WeightLog?, healthLog: DailyHealthLog?) {
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

                Section("Weight") {
                    TextField("Weight kg", text: $draft.weightText)
                        .keyboardType(.decimalPad)
                }

                Section("Calories") {
                    TextField("Total calories", text: $draft.caloriesText)
                        .keyboardType(.numberPad)
                }

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
            .navigationTitle("Health entry")
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
            date: date,
            weightLog: store.weightLog(on: date),
            healthLog: store.dailyHealthLog(on: date)
        )
    }

    private func save() {
        if let weightKg = draft.weightKg {
            store.upsertWeightLog(date: draft.date, weightKg: weightKg)
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
