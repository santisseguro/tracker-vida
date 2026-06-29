import SwiftUI

struct AppCard<Content: View>: View {
    var tint: Color?
    var compact = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            content
        }
        .padding(compact ? 16 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: compact ? AppTheme.Layout.compactRadius : AppTheme.Layout.cardRadius, style: .continuous)
                .fill(tint?.opacity(0.12) ?? AppTheme.Colors.elevatedCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? AppTheme.Layout.compactRadius : AppTheme.Layout.cardRadius, style: .continuous)
                .strokeBorder((tint ?? Color.primary).opacity(tint == nil ? 0.06 : 0.18), lineWidth: 1)
        )
    }
}
