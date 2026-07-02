import Foundation

enum AIChatMessageRole: String, Hashable {
    case user
    case assistant
}

struct AIChatMessage: Hashable, Identifiable {
    var id = EntityID()
    var role: AIChatMessageRole
    var text: String
    var createdAt: Date
}

enum MoneyCommandAccountRole: Hashable {
    case from
    case to

    var questionLabel: String {
        switch self {
        case .from:
            return "origen"
        case .to:
            return "destino"
        }
    }
}

enum PendingMoneyCommandStep: Hashable {
    case accountName(MoneyCommandAccountRole)
    case createAccountConfirmation(MoneyCommandAccountRole, String)
    case initialBalance(MoneyCommandAccountRole, String)
}

struct PendingMoneyCommand: Hashable, Identifiable {
    var id = EntityID()
    var draft: MoneyCommandDraft
    var step: PendingMoneyCommandStep
}

struct MoneyConversationState: Hashable {
    var messages: [AIChatMessage] = []
    var pendingCommand: PendingMoneyCommand?

    var latestAssistantResponse: String? {
        messages.last { $0.role == .assistant }?.text
    }
}

@MainActor
enum MoneyConversationEngine {
    static func handle(_ input: String, state: inout MoneyConversationState, store: AppStore, date: Date = .now) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        append(.user, text, to: &state, date: date)

        if state.pendingCommand != nil {
            handlePendingReply(text, state: &state, store: store, date: date)
            trimMessages(in: &state)
            return
        }

        switch MoneyCommandParser.parse(text, accounts: store.moneyState.activeAccounts, date: date) {
        case .success(let draft):
            continueOrComplete(draft, state: &state, store: store, date: date)
        case .failure:
            append(.assistant, "No lo entendí todavía. Probá con gasto, ingreso, transferencia o saldo real, incluyendo monto y cuenta.", to: &state, date: date)
        }

        trimMessages(in: &state)
    }

    private static func handlePendingReply(_ text: String, state: inout MoneyConversationState, store: AppStore, date: Date) {
        guard var pending = state.pendingCommand else { return }

        switch pending.step {
        case .accountName(let role):
            if let account = matchingAccount(named: text, accounts: store.moneyState.activeAccounts) {
                apply(accountID: account.id, role: role, to: &pending.draft)
                state.pendingCommand = nil
                continueOrComplete(pending.draft, state: &state, store: store, date: date)
            } else {
                let name = cleanedAccountName(from: text)
                state.pendingCommand = PendingMoneyCommand(draft: pending.draft, step: .createAccountConfirmation(role, name))
                append(.assistant, "No tenés ninguna cuenta llamada \(name) registrada. ¿Querés crearla?", to: &state, date: date)
            }
        case .createAccountConfirmation(let role, let name):
            if isAffirmative(text) {
                state.pendingCommand = PendingMoneyCommand(draft: pending.draft, step: .initialBalance(role, name))
                append(.assistant, "¿Con cuánto saldo inicial querés crear \(name)?", to: &state, date: date)
            } else if isNegative(text) {
                state.pendingCommand = PendingMoneyCommand(draft: pending.draft, step: .accountName(role))
                append(.assistant, "Ok. Decime qué cuenta \(role.questionLabel) querés usar.", to: &state, date: date)
            } else if let account = matchingAccount(named: text, accounts: store.moneyState.activeAccounts) {
                apply(accountID: account.id, role: role, to: &pending.draft)
                state.pendingCommand = nil
                continueOrComplete(pending.draft, state: &state, store: store, date: date)
            } else {
                append(.assistant, "Necesito un sí para crear \(name), o decime el nombre de una cuenta existente.", to: &state, date: date)
            }
        case .initialBalance(let role, let name):
            guard let initialBalance = MoneyCommandParser.parseAmountValue(text, defaultCurrency: pending.draft.amount.currency) else {
                append(.assistant, "Decime el saldo inicial con un monto claro, por ejemplo 50000 pesos o 100 USDT.", to: &state, date: date)
                return
            }

            let account = store.addMoneyAccount(
                name: name,
                currency: initialBalance.currency,
                currentBalance: initialBalance.minorUnits,
                createdAt: date
            )
            apply(accountID: account.id, role: role, to: &pending.draft)
            state.pendingCommand = nil
            continueOrComplete(pending.draft, state: &state, store: store, date: date, createdAccount: account)
        }
    }

    private static func continueOrComplete(
        _ draft: MoneyCommandDraft,
        state: inout MoneyConversationState,
        store: AppStore,
        date: Date,
        createdAccount: MoneyAccount? = nil
    ) {
        if draft.requiresFromAccount, draft.fromAccountID == nil {
            askForAccount(role: .from, detectedName: draft.detectedFromAccountName, draft: draft, state: &state, date: date)
            return
        }

        if draft.requiresToAccount, draft.toAccountID == nil {
            askForAccount(role: .to, detectedName: draft.detectedToAccountName, draft: draft, state: &state, date: date)
            return
        }

        guard let response = apply(draft, store: store, createdAccount: createdAccount) else {
            append(.assistant, "No pude registrar eso con los datos actuales. Revisá la cuenta y probá de nuevo.", to: &state, date: date)
            return
        }

        append(.assistant, response, to: &state, date: date)
    }

    private static func askForAccount(
        role: MoneyCommandAccountRole,
        detectedName: String?,
        draft: MoneyCommandDraft,
        state: inout MoneyConversationState,
        date: Date
    ) {
        if let detectedName {
            state.pendingCommand = PendingMoneyCommand(draft: draft, step: .createAccountConfirmation(role, detectedName))
            append(.assistant, "No tenés ninguna cuenta llamada \(detectedName) registrada. ¿Querés crearla?", to: &state, date: date)
        } else {
            state.pendingCommand = PendingMoneyCommand(draft: draft, step: .accountName(role))
            append(.assistant, "¿Qué cuenta \(role.questionLabel) querés usar para este movimiento?", to: &state, date: date)
        }
    }

    private static func apply(_ draft: MoneyCommandDraft, store: AppStore, createdAccount: MoneyAccount?) -> String? {
        switch draft.kind {
        case .income:
            guard let toAccountID = draft.toAccountID,
                  let category = draft.incomeCategory,
                  store.addIncomeTransaction(title: draft.title, amount: draft.amount.minorUnits, toAccountID: toAccountID, category: category, date: draft.date, notes: draft.note) != nil,
                  let account = store.moneyAccount(id: toAccountID)
            else { return nil }

            return doneMessage(
                prefix: createdAccountMessage(createdAccount),
                action: "registré el ingreso de \(formatted(draft.amount))",
                account: account
            )
        case .expense:
            guard let fromAccountID = draft.fromAccountID,
                  let category = draft.expenseCategory,
                  store.addExpenseTransaction(title: draft.title, amount: draft.amount.minorUnits, fromAccountID: fromAccountID, category: category, date: draft.date, notes: draft.note) != nil,
                  let account = store.moneyAccount(id: fromAccountID)
            else { return nil }

            return doneMessage(
                prefix: createdAccountMessage(createdAccount),
                action: "registré el gasto de \(formatted(draft.amount))",
                account: account
            )
        case .transfer:
            guard let fromAccountID = draft.fromAccountID,
                  let toAccountID = draft.toAccountID,
                  store.addTransferTransaction(title: draft.title, amount: draft.amount.minorUnits, fromAccountID: fromAccountID, toAccountID: toAccountID, date: draft.date, notes: draft.note) != nil,
                  let fromAccount = store.moneyAccount(id: fromAccountID),
                  let toAccount = store.moneyAccount(id: toAccountID)
            else { return nil }

            return "\(createdAccountMessage(createdAccount))Listo. Transferí \(formatted(draft.amount)) de \(fromAccount.name) a \(toAccount.name)."
        case .balanceAdjustment:
            guard let accountID = draft.fromAccountID,
                  store.addBalanceAdjustmentTransaction(title: draft.title, accountID: accountID, newBalance: draft.amount.minorUnits, date: draft.date, notes: draft.note) != nil,
                  let account = store.moneyAccount(id: accountID)
            else { return nil }

            return "\(createdAccountMessage(createdAccount))Listo. Ajusté \(account.name) a \(formatted(account.currentBalance))."
        }
    }

    private static func apply(accountID: EntityID, role: MoneyCommandAccountRole, to draft: inout MoneyCommandDraft) {
        switch role {
        case .from:
            draft.fromAccountID = accountID
            draft.detectedFromAccountName = nil
        case .to:
            draft.toAccountID = accountID
            draft.detectedToAccountName = nil
        }
    }

    private static func append(_ role: AIChatMessageRole, _ text: String, to state: inout MoneyConversationState, date: Date) {
        state.messages.append(AIChatMessage(role: role, text: text, createdAt: date))
    }

    private static func trimMessages(in state: inout MoneyConversationState) {
        if state.messages.count > 12 {
            state.messages = Array(state.messages.suffix(12))
        }
    }

    private static func matchingAccount(named text: String, accounts: [MoneyAccount]) -> MoneyAccount? {
        let normalizedText = normalized(cleanedAccountName(from: text))

        if let exact = accounts.first(where: { normalized($0.name) == normalizedText }) {
            return exact
        }

        return accounts.first { account in
            let accountName = normalized(account.name)
            return accountName.contains(normalizedText) || normalizedText.contains(accountName)
        }
    }

    private static func cleanedAccountName(from text: String) -> String {
        text
            .replacingOccurrences(of: #"(?i)^(usar|usa|con|desde|en|de|la|el|cuenta)\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isAffirmative(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        return ["si", "sí", "dale", "ok", "creala", "crealo", "crear", "yes", "yep"].contains { normalizedText.contains($0) }
    }

    private static func isNegative(_ text: String) -> Bool {
        let normalizedText = normalized(text)
        return ["no", "cancel", "cancelar"].contains { normalizedText == $0 || normalizedText.hasPrefix("\($0) ") }
    }

    private static func doneMessage(prefix: String, action: String, account: MoneyAccount) -> String {
        "\(prefix)Listo. \(action). Nuevo saldo: \(formatted(account.currentBalance))."
    }

    private static func createdAccountMessage(_ account: MoneyAccount?) -> String {
        guard let account else { return "" }
        return "Creé \(account.name) con \(formatted(account.currentBalance)). "
    }

    private static func formatted(_ amount: MoneyAmount) -> String {
        switch amount.currency {
        case .ars:
            return "$\(amount.minorUnits.formatted()) ARS"
        case .usdt:
            return "\(amount.minorUnits.formatted()) USDT"
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension MoneyCommandDraft {
    var incomeCategory: IncomeCategory? {
        guard case .income(let category) = category else { return nil }
        return category
    }

    var expenseCategory: ExpenseCategory? {
        guard case .expense(let category) = category else { return nil }
        return category
    }
}
