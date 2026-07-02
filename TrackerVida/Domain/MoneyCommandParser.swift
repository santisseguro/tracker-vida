import Foundation

enum MoneyCommandParseError: LocalizedError, Equatable {
    case unsupportedCommand
    case missingAmount

    var errorDescription: String? {
        switch self {
        case .unsupportedCommand:
            return "I could not understand that money command yet. Try income, expense, transfer, or balance."
        case .missingAmount:
            return "I found the command type, but not a valid amount."
        }
    }
}

struct MoneyCommandDraft: Hashable, Identifiable {
    var id = EntityID()
    var originalText: String
    var kind: MoneyTransactionKind
    var title: String
    var amount: MoneyAmount
    var date: Date
    var fromAccountID: EntityID?
    var toAccountID: EntityID?
    var detectedFromAccountName: String?
    var detectedToAccountName: String?
    var category: MoneyTransactionCategory?
    var note: String?

    var requiresFromAccount: Bool {
        kind == .expense || kind == .transfer || kind == .balanceAdjustment
    }

    var requiresToAccount: Bool {
        kind == .income || kind == .transfer
    }
}

enum MoneyCommandParser {
    static func parse(_ text: String, accounts: [MoneyAccount], date: Date) -> Result<MoneyCommandDraft, MoneyCommandParseError> {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = normalized(trimmedText)

        guard let kind = kind(for: normalizedText) else {
            return .failure(.unsupportedCommand)
        }

        guard let parsedAmount = parseAmount(from: trimmedText) else {
            return .failure(.missingAmount)
        }

        let fromCandidate = detectedFromAccountName(in: trimmedText, kind: kind)
        let toCandidate = detectedToAccountName(in: trimmedText, kind: kind)
        let fromAccount = resolvedAccount(candidate: fromCandidate, fallbackText: trimmedText, accounts: accounts)
        let toAccount = resolvedAccount(candidate: toCandidate, fallbackText: trimmedText, accounts: accounts)
        let inferredCurrency = currency(
            explicitCurrency: parsedAmount.currency,
            kind: kind,
            fromAccount: fromAccount,
            toAccount: toAccount
        )
        let amount = MoneyAmount(minorUnits: parsedAmount.minorUnits, currency: inferredCurrency)

        let draft = MoneyCommandDraft(
            originalText: trimmedText,
            kind: kind,
            title: title(for: kind),
            amount: amount,
            date: date,
            fromAccountID: fromAccount?.id,
            toAccountID: toAccount?.id,
            detectedFromAccountName: unresolvedAccountName(fromCandidate, resolvedAccount: fromAccount),
            detectedToAccountName: unresolvedAccountName(toCandidate, resolvedAccount: toAccount),
            category: category(for: kind, normalizedText: normalizedText),
            note: trimmedText
        )

        return .success(draft)
    }

    static func parseAmountValue(_ text: String, defaultCurrency: CurrencyCode = .ars) -> MoneyAmount? {
        guard let parsedAmount = parseAmount(from: text) else { return nil }
        return MoneyAmount(minorUnits: parsedAmount.minorUnits, currency: parsedAmount.currency ?? defaultCurrency)
    }

    private static func kind(for normalizedText: String) -> MoneyTransactionKind? {
        if containsAny(["transferi", "transfer", "mande", "envie"], in: normalizedText) {
            return .transfer
        }

        if containsAny(["saldo real", "saldo actual", "balance real"], in: normalizedText) {
            return .balanceAdjustment
        }

        if containsAny(["entraron", "acreditaron", "acredito", "recibi", "cobre", "ingreso"], in: normalizedText) {
            return .income
        }

        if containsAny(["gaste", "pague", "compre", "abone"], in: normalizedText) {
            return .expense
        }

        return nil
    }

    private static func parseAmount(from text: String) -> (minorUnits: Int, currency: CurrencyCode?)? {
        let pattern = #"(?i)(\d+(?:[.,]\d{3})*(?:[.,]\d+)?)\s*(pesos?|ars|usdt)?"#
        guard let match = firstMatch(pattern: pattern, in: text),
              let amountRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        let amountText = String(text[amountRange]).filter(\.isNumber)
        guard let amount = Int(amountText), amount > 0 else { return nil }

        let currency: CurrencyCode?
        if let currencyRange = Range(match.range(at: 2), in: text) {
            currency = currencyCode(from: String(text[currencyRange]))
        } else {
            currency = nil
        }

        return (amount, currency)
    }

    private static func detectedFromAccountName(in text: String, kind: MoneyTransactionKind) -> String? {
        switch kind {
        case .expense:
            return firstCapturedText(pattern: #"(?i)\b(?:desde|con)\s+(.+?)(?:$|\s+por\b|\s+en\b)"#, in: text)
                ?? expenseFallbackAccountName(in: text)
        case .transfer:
            return firstCapturedText(pattern: #"(?i)\bde\s+(.+?)\s+a\s+"#, in: text)
        case .balanceAdjustment:
            return firstCapturedText(pattern: #"(?i)\b(?:en|de)\s+(.+?)\s+es\b"#, in: text)
        case .income:
            return nil
        }
    }

    private static func expenseFallbackAccountName(in text: String) -> String? {
        guard let candidate = firstCapturedText(pattern: #"(?i)\ben\s+(.+?)$"#, in: text) else {
            return nil
        }

        let normalizedCandidate = normalized(candidate)
        if case .expense(let category) = category(for: .expense, normalizedText: normalizedCandidate), category != .otro {
            return nil
        }

        return candidate
    }

    private static func detectedToAccountName(in text: String, kind: MoneyTransactionKind) -> String? {
        switch kind {
        case .income:
            return firstCapturedText(pattern: #"(?i)\ben\s+(.+?)(?:$|\s+por\b)"#, in: text)
        case .transfer:
            return firstCapturedText(pattern: #"(?i)\ba\s+(.+?)$"#, in: text)
        case .expense, .balanceAdjustment:
            return nil
        }
    }

    private static func resolvedAccount(candidate: String?, fallbackText: String, accounts: [MoneyAccount]) -> MoneyAccount? {
        if let candidate {
            let normalizedCandidate = normalized(candidate)
            if let account = accounts.first(where: { normalized($0.name) == normalizedCandidate }) {
                return account
            }

            if let account = accounts.first(where: { normalized($0.name).contains(normalizedCandidate) || normalizedCandidate.contains(normalized($0.name)) }) {
                return account
            }
        }

        let normalizedText = normalized(fallbackText)
        return accounts.first { account in
            normalizedText.contains(normalized(account.name))
        }
    }

    private static func unresolvedAccountName(_ candidate: String?, resolvedAccount: MoneyAccount?) -> String? {
        guard resolvedAccount == nil else { return nil }
        return candidate?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func currency(explicitCurrency: CurrencyCode?, kind: MoneyTransactionKind, fromAccount: MoneyAccount?, toAccount: MoneyAccount?) -> CurrencyCode {
        if let explicitCurrency {
            return explicitCurrency
        }

        switch kind {
        case .income:
            return toAccount?.currency ?? .ars
        case .expense, .balanceAdjustment:
            return fromAccount?.currency ?? .ars
        case .transfer:
            return fromAccount?.currency ?? toAccount?.currency ?? .ars
        }
    }

    private static func currencyCode(from text: String) -> CurrencyCode {
        normalized(text).contains("usdt") ? .usdt : .ars
    }

    private static func category(for kind: MoneyTransactionKind, normalizedText: String) -> MoneyTransactionCategory? {
        switch kind {
        case .income:
            if containsAny(["trabajo", "sueldo", "freelance"], in: normalizedText) { return .income(.trabajo) }
            if containsAny(["familia"], in: normalizedText) { return .income(.familia) }
            if containsAny(["venta", "vend"], in: normalizedText) { return .income(.venta) }
            if containsAny(["reembolso"], in: normalizedText) { return .income(.reembolso) }
            return .income(.otro)
        case .expense:
            if containsAny(["comida", "almuerzo", "cena", "comi"], in: normalizedText) { return .expense(.comida) }
            if containsAny(["transporte", "colectivo", "uber", "taxi", "bus"], in: normalizedText) { return .expense(.transporte) }
            if containsAny(["universidad", "facultad"], in: normalizedText) { return .expense(.universidad) }
            if containsAny(["ropa"], in: normalizedText) { return .expense(.ropa) }
            if containsAny(["tecnologia", "compu", "celular"], in: normalizedText) { return .expense(.tecnologia) }
            if containsAny(["salud", "farmacia", "medico"], in: normalizedText) { return .expense(.salud) }
            if containsAny(["suscripcion", "netflix", "spotify"], in: normalizedText) { return .expense(.suscripciones) }
            if containsAny(["salida", "cine", "bar"], in: normalizedText) { return .expense(.salidas) }
            return .expense(.otro)
        case .transfer, .balanceAdjustment:
            return nil
        }
    }

    private static func title(for kind: MoneyTransactionKind) -> String {
        switch kind {
        case .income:
            return "AI income"
        case .expense:
            return "AI expense"
        case .transfer:
            return "AI transfer"
        case .balanceAdjustment:
            return "AI balance adjustment"
        }
    }

    private static func containsAny(_ terms: [String], in text: String) -> Bool {
        terms.contains { text.contains($0) }
    }

    private static func firstCapturedText(pattern: String, in text: String) -> String? {
        guard let match = firstMatch(pattern: pattern, in: text),
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
