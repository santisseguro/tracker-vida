import Charts
import SwiftUI

struct MoneyView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activeSheet: MoneySheet?
    @State private var primaryCurrency: CurrencyCode = .usdt
    @State private var trendRange: MoneyTrendRange = .daily

    private var state: MoneyViewState { store.moneyState }

    var body: some View {
        ScreenScaffold(
            title: "Balances",
            subtitle: "ARS, USDT, account balances, recent movements, and text registration preview."
        ) {
            AppCard(tint: AppTheme.Colors.money) {
                HStack {
                    StatusPill(text: "\(state.activeAccounts.count) accounts", tint: AppTheme.Colors.money)
                    Spacer()
                    Text("Local preview")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.money)
                }

                Text("Total available")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Primary total", selection: $primaryCurrency) {
                    Text("USDT").tag(CurrencyCode.usdt)
                    Text("ARS").tag(CurrencyCode.ars)
                }
                .pickerStyle(.segmented)

                HStack(alignment: .lastTextBaseline) {
                    Text(primaryTotalText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.72)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(secondaryTotalText)
                            .font(.title2.weight(.bold))
                        Text(secondaryCurrencyLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AppCard(compact: true) {
                Text("Register")
                    .font(.headline.weight(.bold))

                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        MoneyActionButton(title: "Add account", symbol: "plus.circle.fill", tint: AppTheme.Colors.money) {
                            activeSheet = .addAccount
                        }
                        MoneyActionButton(title: "Add income", symbol: "arrow.down.circle.fill", tint: AppTheme.Colors.health) {
                            activeSheet = .transaction(.income)
                        }
                    }

                    GridRow {
                        MoneyActionButton(title: "Add expense", symbol: "arrow.up.circle.fill", tint: AppTheme.Colors.university) {
                            activeSheet = .transaction(.expense)
                        }
                        MoneyActionButton(title: "Transfer", symbol: "arrow.left.arrow.right.circle.fill", tint: AppTheme.Colors.primary) {
                            activeSheet = .transaction(.transfer)
                        }
                    }

                    MoneyActionButton(title: "Adjust", symbol: "slider.horizontal.3", tint: AppTheme.Colors.warning) {
                        activeSheet = .transaction(.balanceAdjustment)
                    }
                    .gridCellColumns(2)
                }
            }

            AppCard {
                HStack {
                    Text("Balance trends")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "Local", tint: AppTheme.Colors.money)
                }

                Picker("Trend range", selection: $trendRange) {
                    ForEach(MoneyTrendRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                MoneyBalanceTrendChart(
                    accounts: state.activeAccounts,
                    transactions: state.transactions,
                    referenceDate: store.currentDate,
                    usdtToARSRate: state.totals.mockUSDTToARSRate,
                    range: trendRange
                )

                Text("\(trendRange.detail) ARS-equivalent trend from current balances and local transactions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            AppCard {
                Text("Accounts and movement")
                    .font(.headline.weight(.bold))

                ForEach(state.activeAccounts) { account in
                    MoneyAccountActionRow(account: account) {
                        activeSheet = .editAccount(account.id)
                    }
                }

                Divider()

                ForEach(state.transactions) { movement in
                    MoneyMovementRow(
                        transaction: movement,
                        amount: formattedAmount(for: movement),
                        symbol: symbol(for: movement),
                        tint: tint(for: movement)
                    )
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addAccount:
                MoneyAccountFormView(sheet: sheet)
                    .environmentObject(store)
            case .editAccount:
                MoneyAccountFormView(sheet: sheet)
                    .environmentObject(store)
            case .transaction(let kind):
                MoneyTransactionFormView(kind: kind)
                    .environmentObject(store)
            }
        }
    }

    private var primaryTotalText: String {
        switch primaryCurrency {
        case .ars:
            return state.totals.arsDisplay
        case .usdt:
            return "\(usdtEquivalentText) USDT"
        }
    }

    private var secondaryTotalText: String {
        switch primaryCurrency {
        case .ars:
            return "\(usdtEquivalentText)"
        case .usdt:
            return state.totals.arsDisplay
        }
    }

    private var secondaryCurrencyLabel: String {
        primaryCurrency == .ars ? "USDT" : "ARS"
    }

    private var usdtEquivalentText: String {
        let total = Double(state.totals.arsMinorUnits) / Double(state.totals.mockUSDTToARSRate) + Double(state.totals.usdtMinorUnits)
        return total.formatted(.number.precision(.fractionLength(total.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)))
    }

    private func formattedAmount(for transaction: MoneyTransaction) -> String {
        let prefix: String
        switch transaction.kind {
        case .income:
            prefix = "+"
        case .expense:
            prefix = "-"
        case .balanceAdjustment:
            prefix = transaction.amount.minorUnits >= 0 ? "+" : ""
        case .transfer:
            prefix = ""
        }

        let amount = abs(transaction.amount.minorUnits)
        switch transaction.amount.currency {
        case .ars:
            return "\(prefix)$\(amount.formatted())"
        case .usdt:
            return "\(prefix)\(amount.formatted()) USDT"
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

enum MoneyTrendRange: String, CaseIterable, Identifiable {
    case daily
    case monthly
    case annual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        }
    }

    var detail: String {
        switch self {
        case .daily:
            return "Last 7 days."
        case .monthly:
            return "Last 30 days."
        case .annual:
            return "Last 12 months."
        }
    }

    func startDate(referenceDate: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let value: Int

        switch self {
        case .daily:
            component = .day
            value = -6
        case .monthly:
            component = .day
            value = -29
        case .annual:
            component = .year
            value = -1
        }

        return calendar.date(byAdding: component, value: value, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
    }

    var visibleDomainLength: TimeInterval {
        let day: TimeInterval = 60 * 60 * 24

        switch self {
        case .daily:
            return day * 3
        case .monthly:
            return day * 12
        case .annual:
            return day * 31 * 4
        }
    }
}

extension MoneyAccountColor {
    var tint: Color {
        switch self {
        case .money:
            return AppTheme.Colors.money
        case .primary:
            return AppTheme.Colors.primary
        case .health:
            return AppTheme.Colors.health
        case .university:
            return AppTheme.Colors.university
        case .warning:
            return AppTheme.Colors.warning
        case .ai:
            return AppTheme.Colors.ai
        }
    }
}

struct MoneyBalanceTrendChart: View {
    var accounts: [MoneyAccount]
    var transactions: [MoneyTransaction]
    var referenceDate: Date
    var usdtToARSRate: Int
    var range: MoneyTrendRange
    var compact: Bool = false

    private var trendPoints: [MoneyBalanceTrendPoint] {
        MoneyBalanceTrendCalculator.points(
            accounts: accounts,
            transactions: transactions,
            referenceDate: referenceDate,
            usdtToARSRate: usdtToARSRate,
            range: range
        )
    }

    private var hasEnoughTrendData: Bool {
        Dictionary(grouping: trendPoints, by: \.accountID).values.contains { points in
            points.count >= 2 && Set(points.map(\.balanceMinorUnits)).count >= 1
        }
    }

    var body: some View {
        if hasEnoughTrendData {
            if compact {
                trendChart
                    .frame(height: 96)
                    .chartXScale(domain: xAxisDomain)
                    .chartXAxis {
                        AxisMarks(values: axisMarkValues) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(axisLabel(for: date))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
            } else {
                trendChart
                    .frame(height: 180)
                    .chartXScale(domain: xAxisDomain)
                    .chartScrollableAxes(.horizontal)
                    .chartXVisibleDomain(length: range.visibleDomainLength)
                    .chartScrollPosition(initialX: initialScrollPosition)
                    .chartXAxis {
                        AxisMarks(values: axisMarkValues) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(axisLabel(for: date))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let amount = value.as(Int.self) {
                                    Text("$\(amount / 1_000)K")
                                }
                            }
                        }
                    }

                MoneyAccountColorLegend(accounts: accounts)
            }
        } else {
            MoneyBalanceTrendLimitedDataView(compact: compact)
        }
    }

    private func trendPoints(for account: MoneyAccount) -> [MoneyBalanceTrendPoint] {
        trendPoints.filter { $0.accountID == account.id }
    }

    @ViewBuilder
    private var trendChart: some View {
        Chart {
            ForEach(accounts) { account in
                ForEach(trendPoints(for: account)) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("ARS equivalent", point.arsEquivalent),
                        series: .value("Account", account.name)
                    )
                    .foregroundStyle(account.color.tint)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("ARS equivalent", point.arsEquivalent)
                    )
                    .foregroundStyle(account.color.tint)
                }
            }
        }
    }

    private var xAxisDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        return range.startDate(referenceDate: referenceDate, calendar: calendar)...referenceDate
    }

    private var initialScrollPosition: Date {
        max(xAxisDomain.lowerBound, referenceDate.addingTimeInterval(-range.visibleDomainLength))
    }

    private var axisMarkValues: AxisMarkValues {
        if compact {
            switch range {
            case .daily:
                return .stride(by: .day, count: 3)
            case .monthly:
                return .stride(by: .day, count: 14)
            case .annual:
                return .stride(by: .month, count: 4)
            }
        }

        switch range {
        case .daily:
            return .stride(by: .day, count: 1)
        case .monthly:
            return .stride(by: .day, count: 7)
        case .annual:
            return .stride(by: .month, count: 3)
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch range {
        case .daily:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .monthly:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .annual:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

private struct MoneyBalanceTrendLimitedDataView: View {
    var compact: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font((compact ? Font.subheadline : Font.title3).weight(.bold))
                .foregroundStyle(AppTheme.Colors.money)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(AppTheme.Colors.money.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Not enough movement yet")
                    .font(.subheadline.weight(.semibold))
                Text("Register movements to build account trends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.elevatedCard, in: RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous))
    }
}

private struct MoneyActionButton: View {
    var title: String
    var symbol: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(AppTheme.Colors.elevatedCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct MoneyAccountColorLegend: View {
    var accounts: [MoneyAccount]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(accounts) { account in
                HStack(spacing: 6) {
                    Circle()
                        .fill(account.color.tint)
                        .frame(width: 8, height: 8)

                    Text(account.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .padding(.top, 2)
    }
}

private struct MoneyAccountActionRow: View {
    var account: MoneyAccount
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(account.color.tint)
                .frame(width: 28, height: 28)
                .background(account.color.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                Text(account.currency.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(formattedBalance)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)

            Button(action: action) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(account.color.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(account.name)")
        }
        .padding(.vertical, 4)
    }

    private var formattedBalance: String {
        switch account.currentBalance.currency {
        case .ars:
            return "$\(account.currentBalance.minorUnits.formatted())"
        case .usdt:
            return "\(account.currentBalance.minorUnits.formatted())"
        }
    }
}

private struct MoneyMovementRow: View {
    var transaction: MoneyTransaction
    var amount: String
    var symbol: String
    var tint: Color

    private var detail: String {
        transaction.category?.label ?? transaction.kind.rawValue
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let note = transaction.notes {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            Text(amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MoneyBalanceTrendPoint: Identifiable {
    var accountID: EntityID
    var accountName: String
    var date: Date
    var balanceMinorUnits: Int
    var currency: CurrencyCode
    var usdtToARSRate: Int

    var id: String {
        "\(accountID.uuidString)-\(date.timeIntervalSince1970)-\(balanceMinorUnits)"
    }

    var arsEquivalent: Int {
        switch currency {
        case .ars:
            return balanceMinorUnits
        case .usdt:
            return balanceMinorUnits * usdtToARSRate
        }
    }
}

enum MoneyBalanceTrendCalculator {
    static func points(
        accounts: [MoneyAccount],
        transactions: [MoneyTransaction],
        referenceDate: Date,
        usdtToARSRate: Int,
        range: MoneyTrendRange,
        calendar: Calendar = .current
    ) -> [MoneyBalanceTrendPoint] {
        accounts.flatMap { account in
            points(
                for: account,
                transactions: transactions,
                referenceDate: referenceDate,
                usdtToARSRate: usdtToARSRate,
                range: range,
                calendar: calendar
            )
        }
    }

    private static func points(
        for account: MoneyAccount,
        transactions: [MoneyTransaction],
        referenceDate: Date,
        usdtToARSRate: Int,
        range: MoneyTrendRange,
        calendar: Calendar
    ) -> [MoneyBalanceTrendPoint] {
        let sortedTransactions = transactions.sorted { $0.date > $1.date }
        let startDate = range.startDate(referenceDate: referenceDate, calendar: calendar)

        if range == .annual {
            return annualPoints(
                for: account,
                transactions: sortedTransactions,
                referenceDate: referenceDate,
                startDate: startDate,
                usdtToARSRate: usdtToARSRate,
                calendar: calendar
            )
        }

        var runningBalance = account.currentBalance.minorUnits
        var points = [
            point(
                for: account,
                date: startDate,
                balance: balance(for: account, at: startDate, currentBalance: account.currentBalance.minorUnits, transactions: sortedTransactions, usdtToARSRate: usdtToARSRate),
                usdtToARSRate: usdtToARSRate
            ),
            point(for: account, date: referenceDate, balance: runningBalance, usdtToARSRate: usdtToARSRate)
        ]

        for transaction in sortedTransactions {
            guard let priorBalance = priorBalance(
                for: account,
                currentBalance: runningBalance,
                transaction: transaction,
                usdtToARSRate: usdtToARSRate
            ) else {
                continue
            }

            runningBalance = priorBalance
            points.append(point(for: account, date: transaction.date, balance: runningBalance, usdtToARSRate: usdtToARSRate))
        }

        let orderedPoints = points.reversed()
        return deduplicatedSortedPoints(orderedPoints.filter { $0.date >= startDate && $0.date <= referenceDate })
    }

    private static func annualPoints(
        for account: MoneyAccount,
        transactions: [MoneyTransaction],
        referenceDate: Date,
        startDate: Date,
        usdtToARSRate: Int,
        calendar: Calendar
    ) -> [MoneyBalanceTrendPoint] {
        var sampleDates: [Date] = []
        var cursor = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate

        while cursor <= referenceDate {
            sampleDates.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? referenceDate.addingTimeInterval(1)
        }

        sampleDates.append(referenceDate)

        return deduplicatedSortedPoints(
            sampleDates.map { sampleDate in
                point(
                    for: account,
                    date: sampleDate,
                    balance: balance(
                        for: account,
                        at: sampleDate,
                        currentBalance: account.currentBalance.minorUnits,
                        transactions: transactions,
                        usdtToARSRate: usdtToARSRate
                    ),
                    usdtToARSRate: usdtToARSRate
                )
            }
        )
    }

    private static func balance(
        for account: MoneyAccount,
        at date: Date,
        currentBalance: Int,
        transactions: [MoneyTransaction],
        usdtToARSRate: Int
    ) -> Int {
        var balance = currentBalance

        for transaction in transactions where transaction.date > date {
            guard let priorBalance = priorBalance(
                for: account,
                currentBalance: balance,
                transaction: transaction,
                usdtToARSRate: usdtToARSRate
            ) else {
                continue
            }

            balance = priorBalance
        }

        return balance
    }

    private static func deduplicatedSortedPoints(_ points: [MoneyBalanceTrendPoint]) -> [MoneyBalanceTrendPoint] {
        points
            .sorted { $0.date < $1.date }
            .reduce(into: [MoneyBalanceTrendPoint]()) { result, point in
                if let lastIndex = result.indices.last, result[lastIndex].accountID == point.accountID, result[lastIndex].date == point.date {
                    result[lastIndex] = point
                } else {
                    result.append(point)
                }
            }
    }

    private static func point(for account: MoneyAccount, date: Date, balance: Int, usdtToARSRate: Int) -> MoneyBalanceTrendPoint {
        MoneyBalanceTrendPoint(
            accountID: account.id,
            accountName: account.name,
            date: date,
            balanceMinorUnits: balance,
            currency: account.currency,
            usdtToARSRate: usdtToARSRate
        )
    }

    private static func priorBalance(
        for account: MoneyAccount,
        currentBalance: Int,
        transaction: MoneyTransaction,
        usdtToARSRate: Int
    ) -> Int? {
        switch transaction.kind {
        case .income:
            guard transaction.toAccountID == account.id else { return nil }
            return currentBalance - converted(transaction.amount, to: account.currency, usdtToARSRate: usdtToARSRate)
        case .expense:
            guard transaction.fromAccountID == account.id else { return nil }
            return currentBalance + converted(transaction.amount, to: account.currency, usdtToARSRate: usdtToARSRate)
        case .transfer:
            if transaction.fromAccountID == account.id {
                return currentBalance + converted(transaction.amount, to: account.currency, usdtToARSRate: usdtToARSRate)
            }

            if transaction.toAccountID == account.id {
                return currentBalance - converted(transaction.amount, to: account.currency, usdtToARSRate: usdtToARSRate)
            }

            return nil
        case .balanceAdjustment:
            guard transaction.fromAccountID == account.id || transaction.toAccountID == account.id else { return nil }

            if transaction.balanceBefore?.currency == account.currency {
                return transaction.balanceBefore?.minorUnits
            }

            return currentBalance - converted(transaction.amount, to: account.currency, usdtToARSRate: usdtToARSRate)
        }
    }

    private static func converted(_ amount: MoneyAmount, to currency: CurrencyCode, usdtToARSRate: Int) -> Int {
        guard amount.currency != currency else { return amount.minorUnits }

        switch (amount.currency, currency) {
        case (.ars, .usdt):
            return amount.minorUnits / usdtToARSRate
        case (.usdt, .ars):
            return amount.minorUnits * usdtToARSRate
        default:
            return amount.minorUnits
        }
    }
}

private enum MoneySheet: Identifiable {
    case addAccount
    case editAccount(EntityID)
    case transaction(MoneyTransactionKind)

    var id: String {
        switch self {
        case .addAccount:
            return "add-account"
        case let .editAccount(accountID):
            return "edit-account-\(accountID.uuidString)"
        case let .transaction(kind):
            return "transaction-\(kind.rawValue)"
        }
    }
}

private struct MoneyAccountDraft {
    var name: String
    var currency: CurrencyCode
    var balanceText: String
    var isActive: Bool
    var color: MoneyAccountColor

    init(account: MoneyAccount?) {
        name = account?.name ?? ""
        currency = account?.currency ?? .ars
        balanceText = account?.currentBalance.minorUnits.formatted() ?? ""
        isActive = account?.status != .archived
        color = account?.color ?? .money
    }

    var balance: Int {
        Int(moneyText: balanceText) ?? 0
    }
}

private struct MoneyAccountFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = MoneyAccountDraft(account: nil)

    let sheet: MoneySheet

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $draft.name)

                    Picker("Currency", selection: $draft.currency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }

                    TextField("Current balance", text: $draft.balanceText)
                        .keyboardType(.numberPad)

                    Toggle("Active", isOn: $draft.isActive)
                }

                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(MoneyAccountColor.allCases) { color in
                            Button {
                                draft.color = color
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(color.tint)
                                            .frame(width: 34, height: 34)

                                        if draft.color == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text(color.label)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color.label)
                            .accessibilityValue(draft.color == color ? "Selected" : "")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(navigationTitle)
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
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                loadDraft()
            }
        }
    }

    private var navigationTitle: String {
        switch sheet {
        case .addAccount:
            return "New account"
        case .editAccount:
            return "Edit account"
        case .transaction:
            return "Account"
        }
    }

    private func loadDraft() {
        guard case let .editAccount(accountID) = sheet else {
            draft = MoneyAccountDraft(account: nil)
            return
        }

        draft = MoneyAccountDraft(account: store.moneyAccount(id: accountID))
    }

    private func save() {
        let status: MoneyAccountStatus = draft.isActive ? .active : .archived

        switch sheet {
        case .addAccount:
            store.addMoneyAccount(
                name: draft.name,
                currency: draft.currency,
                currentBalance: draft.balance,
                status: status,
                color: draft.color
            )
        case let .editAccount(accountID):
            guard var account = store.moneyAccount(id: accountID) else { return }

            account.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            account.currency = draft.currency
            account.currentBalance = MoneyAmount(minorUnits: draft.balance, currency: draft.currency)
            account.status = status
            account.color = draft.color

            store.updateMoneyAccount(account)
        case .transaction:
            break
        }
    }
}

private struct MoneyTransactionDraft {
    var title: String
    var amountText: String
    var newBalanceText: String
    var notes: String
    var date: Date
    var fromAccountID: EntityID?
    var toAccountID: EntityID?
    var incomeCategory: IncomeCategory
    var expenseCategory: ExpenseCategory

    init(kind: MoneyTransactionKind, accounts: [MoneyAccount], date: Date) {
        title = kind.rawValue
        amountText = ""
        newBalanceText = ""
        notes = ""
        self.date = date
        fromAccountID = accounts.first?.id
        toAccountID = accounts.dropFirst().first?.id ?? accounts.first?.id
        incomeCategory = .trabajo
        expenseCategory = .comida
    }

    var amount: Int {
        Int(moneyText: amountText) ?? 0
    }

    var newBalance: Int {
        Int(moneyText: newBalanceText) ?? 0
    }
}

private struct MoneyTransactionFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MoneyTransactionDraft

    let kind: MoneyTransactionKind

    init(kind: MoneyTransactionKind) {
        self.kind = kind
        _draft = State(initialValue: MoneyTransactionDraft(kind: kind, accounts: [], date: .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Title", text: $draft.title)

                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)

                    if kind == .balanceAdjustment {
                        TextField("New balance", text: $draft.newBalanceText)
                            .keyboardType(.numberPad)
                    } else {
                        TextField("Amount", text: $draft.amountText)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Accounts") {
                    if kind == .income {
                        accountPicker("Destination account", selection: $draft.toAccountID)
                    } else if kind == .expense || kind == .balanceAdjustment {
                        accountPicker("Origin account", selection: $draft.fromAccountID)
                    } else {
                        accountPicker("Origin account", selection: $draft.fromAccountID)
                        accountPicker("Destination account", selection: $draft.toAccountID)
                    }
                }

                if kind == .income {
                    Section("Category") {
                        Picker("Income category", selection: $draft.incomeCategory) {
                            ForEach(IncomeCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                    }
                } else if kind == .expense {
                    Section("Category") {
                        Picker("Expense category", selection: $draft.expenseCategory) {
                            ForEach(ExpenseCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                    }
                }
            }
            .navigationTitle(kind.rawValue)
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
                    .disabled(!canSave)
                }
            }
            .onAppear {
                loadDraftIfNeeded()
            }
        }
    }

    private var activeAccounts: [MoneyAccount] {
        store.moneyState.activeAccounts
    }

    private var canSave: Bool {
        let hasTitle = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        switch kind {
        case .income:
            return hasTitle && draft.amount > 0 && draft.toAccountID != nil
        case .expense:
            return hasTitle && draft.amount > 0 && draft.fromAccountID != nil
        case .transfer:
            return hasTitle && draft.amount > 0 && draft.fromAccountID != nil && draft.toAccountID != nil && draft.fromAccountID != draft.toAccountID
        case .balanceAdjustment:
            return hasTitle && draft.fromAccountID != nil
        }
    }

    @ViewBuilder
    private func accountPicker(_ title: String, selection: Binding<EntityID?>) -> some View {
        Picker(title, selection: selection) {
            ForEach(activeAccounts) { account in
                Text("\(account.name) \(account.currency.rawValue)").tag(Optional(account.id))
            }
        }
    }

    private func loadDraftIfNeeded() {
        guard draft.fromAccountID == nil, draft.toAccountID == nil else { return }

        draft = MoneyTransactionDraft(kind: kind, accounts: activeAccounts, date: store.currentDate)
    }

    private func save() {
        switch kind {
        case .income:
            guard let toAccountID = draft.toAccountID else { return }
            store.addIncomeTransaction(title: draft.title, amount: draft.amount, toAccountID: toAccountID, category: draft.incomeCategory, date: draft.date, notes: draft.notes)
        case .expense:
            guard let fromAccountID = draft.fromAccountID else { return }
            store.addExpenseTransaction(title: draft.title, amount: draft.amount, fromAccountID: fromAccountID, category: draft.expenseCategory, date: draft.date, notes: draft.notes)
        case .transfer:
            guard let fromAccountID = draft.fromAccountID, let toAccountID = draft.toAccountID else { return }
            store.addTransferTransaction(title: draft.title, amount: draft.amount, fromAccountID: fromAccountID, toAccountID: toAccountID, date: draft.date, notes: draft.notes)
        case .balanceAdjustment:
            guard let accountID = draft.fromAccountID else { return }
            store.addBalanceAdjustmentTransaction(title: draft.title, accountID: accountID, newBalance: draft.newBalance, date: draft.date, notes: draft.notes)
        }
    }
}

private extension Int {
    init?(moneyText: String) {
        let filtered = moneyText.filter { $0.isNumber || $0 == "-" }
        guard !filtered.isEmpty else { return nil }
        self.init(filtered)
    }
}
