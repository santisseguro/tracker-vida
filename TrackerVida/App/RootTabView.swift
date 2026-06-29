import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }

            GymHealthView()
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }

            UniversityView()
                .tabItem {
                    Label("University", systemImage: "graduationcap.fill")
                }

            MoneyView()
                .tabItem {
                    Label("Money", systemImage: "creditcard.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AppTheme.Colors.primary)
    }
}
