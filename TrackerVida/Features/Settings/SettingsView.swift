import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScreenScaffold(
            title: "Configuration",
            subtitle: "Placeholder controls for future privacy, data, and integration settings."
        ) {
            AppCard {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.Colors.primary)
                        Text("TV")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 62, height: 62)

                    VStack(alignment: .leading, spacing: 8) {
                        StatusPill(text: "Private v1", tint: AppTheme.Colors.primary)
                        Text("Tracker Vida")
                            .font(.title3.weight(.bold))
                        Text("Static SwiftUI shell only. No persistence or integrations are connected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AppCard {
                Text("Configuration sections")
                    .font(.headline.weight(.bold))

                ForEach(MockData.settingsSections) { section in
                    InfoRow(title: section.title, detail: section.detail, value: section.value, symbol: "switch.2", tint: AppTheme.Colors.primary)
                }
            }

            AppCard(tint: AppTheme.Colors.ai, compact: true) {
                Text("Future controls")
                    .font(.headline.weight(.bold))
                InfoRow(title: "Backup", detail: "Export and restore personal data", value: "Later", symbol: "externaldrive.fill", tint: AppTheme.Colors.ai)
                InfoRow(title: "Defaults", detail: "Targets and currencies", value: "Later", symbol: "slider.horizontal.3", tint: AppTheme.Colors.ai)
                InfoRow(title: "Integrations", detail: "HealthKit, Supabase, AI", value: "Later", symbol: "link", tint: AppTheme.Colors.ai)
            }
        }
    }
}
