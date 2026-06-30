import SwiftUI

struct MoneyView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activeSheet: MoneySheet?

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

                HStack(alignment: .lastTextBaseline) {
                    Text(state.totals.arsDisplay)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(state.totals.usdtDisplay)
                            .font(.title2.weight(.bold))
                        Text("USDT")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                activeSheet = .addAccount
            }

            AppCard {
                Text("Accounts and movement")
                    .font(.headline.weight(.bold))

                ForEach(state.accountBalances) { balance in
                    InfoRow(title: balance.title, detail: balance.detail, value: balance.value, symbol: "wallet.pass.fill", tint: AppTheme.Colors.money)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activeSheet = .editAccount(balance.id)
                        }
                }

                Divider()

                ForEach(state.transactions) { movement in
                    InfoRow(title: movement.title, detail: movement.category?.label ?? movement.kind.rawValue, value: formattedAmount(for: movement), symbol: symbol(for: movement), tint: tint(for: movement))
                }
            }
            .contextMenu {
                Button("Add income") {
                    activeSheet = .transaction(.income)
                }
                Button("Add expense") {
                    activeSheet = .transaction(.expense)
                }
                Button("Add transfer") {
                    activeSheet = .transaction(.transfer)
                }
                Button("Balance adjustment") {
                    activeSheet = .transaction(.balanceAdjustment)
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

    init(account: MoneyAccount?) {
        name = account?.name ?? ""
        currency = account?.currency ?? .ars
        balanceText = account?.currentBalance.minorUnits.formatted() ?? ""
        isActive = account?.status != .archived
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
                status: status
            )
        case let .editAccount(accountID):
            guard var account = store.moneyAccount(id: accountID) else { return }

            account.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            account.currency = draft.currency
            account.currentBalance = MoneyAmount(minorUnits: draft.balance, currency: draft.currency)
            account.status = status

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
    var date: Date
    var fromAccountID: EntityID?
    var toAccountID: EntityID?
    var incomeCategory: IncomeCategory
    var expenseCategory: ExpenseCategory

    init(kind: MoneyTransactionKind, accounts: [MoneyAccount], date: Date) {
        title = kind.rawValue
        amountText = ""
        newBalanceText = ""
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
            store.addIncomeTransaction(title: draft.title, amount: draft.amount, toAccountID: toAccountID, category: draft.incomeCategory, date: draft.date)
        case .expense:
            guard let fromAccountID = draft.fromAccountID else { return }
            store.addExpenseTransaction(title: draft.title, amount: draft.amount, fromAccountID: fromAccountID, category: draft.expenseCategory, date: draft.date)
        case .transfer:
            guard let fromAccountID = draft.fromAccountID, let toAccountID = draft.toAccountID else { return }
            store.addTransferTransaction(title: draft.title, amount: draft.amount, fromAccountID: fromAccountID, toAccountID: toAccountID, date: draft.date)
        case .balanceAdjustment:
            guard let accountID = draft.fromAccountID else { return }
            store.addBalanceAdjustmentTransaction(title: draft.title, accountID: accountID, newBalance: draft.newBalance, date: draft.date)
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
