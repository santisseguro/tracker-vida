import SwiftUI

struct MoneyView: View {
    private var activeAccounts: [MoneyAccount] {
        MockData.moneyAccounts.filter { $0.status == .active }
    }

    var body: some View {
        ScreenScaffold(
            title: "Balances",
            subtitle: "ARS, USDT, account balances, recent movements, and text registration preview."
        ) {
            AppCard(tint: AppTheme.Colors.money) {
                HStack {
                    StatusPill(text: "\(activeAccounts.count) accounts", tint: AppTheme.Colors.money)
                    Spacer()
                    Text("Static preview")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.money)
                }

                Text("Total available")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline) {
                    Text("$501.300")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("1.240")
                            .font(.title2.weight(.bold))
                        Text("USDT")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AppCard {
                Text("Accounts and movement")
                    .font(.headline.weight(.bold))

                ForEach(MockData.accountBalances) { balance in
                    InfoRow(title: balance.title, detail: balance.detail, value: balance.value, symbol: "wallet.pass.fill", tint: AppTheme.Colors.money)
                }

                Divider()

                ForEach(MockData.moneyTransactions) { movement in
                    InfoRow(title: movement.title, detail: movement.category?.label ?? movement.kind.rawValue, value: formattedAmount(for: movement), symbol: symbol(for: movement), tint: tint(for: movement))
                }
            }

            AppCard(tint: AppTheme.Colors.ai, compact: true) {
                HStack {
                    Text("AI text input preview")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Mock only", tint: AppTheme.Colors.ai)
                }

                Text("gaste 11500 en comida del efectivo")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.elevatedCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                InfoRow(title: "Detected as expense", detail: "Comida", value: "-$11.500", symbol: "text.bubble.fill", tint: AppTheme.Colors.ai)
            }
        }
    }

    private func formattedAmount(for transaction: MoneyTransaction) -> String {
        let prefix = transaction.kind == .expense ? "-" : transaction.kind == .income ? "+" : ""
        switch transaction.amount.currency {
        case .ars:
            return "\(prefix)$\(transaction.amount.minorUnits.formatted())"
        case .usdt:
            return "\(prefix)\(transaction.amount.minorUnits) USDT"
        }
    }

    private func symbol(for transaction: MoneyTransaction) -> String {
        switch transaction.kind {
        case .income:
            return "arrow.down.circle.fill"
        case .expense:
            return "arrow.up.circle.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        case .balanceAdjustment:
            return "slider.horizontal.3"
        }
    }

    private func tint(for transaction: MoneyTransaction) -> Color {
        switch transaction.kind {
        case .income:
            return AppTheme.Colors.health
        case .expense:
            return AppTheme.Colors.university
        case .transfer, .balanceAdjustment:
            return AppTheme.Colors.primary
        }
    }
}
