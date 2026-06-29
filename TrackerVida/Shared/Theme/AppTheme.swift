import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppTheme {
    enum Colors {
        #if os(iOS)
        static let background = Color(uiColor: .systemGroupedBackground)
        static let card = Color(uiColor: .secondarySystemGroupedBackground)
        static let elevatedCard = Color(uiColor: .systemBackground)
        #elseif os(macOS)
        static let background = Color(nsColor: .windowBackgroundColor)
        static let card = Color(nsColor: .controlBackgroundColor)
        static let elevatedCard = Color(nsColor: .textBackgroundColor)
        #else
        static let background = Color.gray.opacity(0.12)
        static let card = Color.gray.opacity(0.08)
        static let elevatedCard = Color.white
        #endif
        static let primary = Color.blue
        static let health = Color.green
        static let university = Color.red
        static let money = Color.cyan
        static let ai = Color.purple
        static let warning = Color.orange
    }

    enum Layout {
        static let screenPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 16
        static let cardRadius: CGFloat = 28
        static let compactRadius: CGFloat = 20
    }
}
