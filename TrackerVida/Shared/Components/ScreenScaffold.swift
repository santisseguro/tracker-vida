import SwiftUI

struct ScreenScaffold<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Layout.cardSpacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)

                    content
                }
                .padding(.horizontal, AppTheme.Layout.screenPadding)
                .padding(.bottom, 28)
            }
            .background(AppTheme.Colors.background)
        }
    }
}
