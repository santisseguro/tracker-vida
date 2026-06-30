import Foundation

enum CurrencyCode: String, CaseIterable, Codable, Identifiable {
    case ars = "ARS"
    case usdt = "USDT"

    var id: String { rawValue }
}

enum MoneyAccountKind: String, CaseIterable, Codable, Identifiable {
    case cash = "Cash"
    case bank = "Bank"
    case digitalWallet = "Digital Wallet"
    case cryptoWallet = "Crypto Wallet"
    case other = "Other"

    var id: String { rawValue }
}

enum MoneyAccountStatus: String, CaseIterable, Codable, Identifiable {
    case active = "Active"
    case archived = "Archived"

    var id: String { rawValue }
}

enum MoneyTransactionKind: String, CaseIterable, Codable, Identifiable {
    case income = "Income"
    case expense = "Expense"
    case transfer = "Transfer"
    case balanceAdjustment = "Balance Adjustment"

    var id: String { rawValue }
}

enum IncomeCategory: String, CaseIterable, Codable, Identifiable {
    case trabajo = "Trabajo"
    case familia = "Familia"
    case venta = "Venta"
    case reembolso = "Reembolso"
    case otro = "Otro"

    var id: String { rawValue }
}

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case comida = "Comida"
    case transporte = "Transporte"
    case universidad = "Universidad"
    case ropa = "Ropa"
    case tecnologia = "Tecnología"
    case salud = "Salud"
    case suscripciones = "Suscripciones"
    case salidas = "Salidas"
    case otro = "Otro"

    var id: String { rawValue }
}

enum MoneyTransactionCategory: Codable, Hashable {
    case income(IncomeCategory)
    case expense(ExpenseCategory)

    var label: String {
        switch self {
        case .income(let category):
            category.rawValue
        case .expense(let category):
            category.rawValue
        }
    }
}

struct MoneyAmount: Codable, Hashable {
    var minorUnits: Int
    var currency: CurrencyCode
}

struct MoneyAccount: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var name: String
    var currency: CurrencyCode
    var currentBalance: MoneyAmount
    var kind: MoneyAccountKind
    var status: MoneyAccountStatus
    var notes: String? = nil

    var id: EntityID { metadata.id }
}

struct AccountBalance: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var accountID: EntityID
    var balance: MoneyAmount
    var recordedOn: Date
    var notes: String? = nil

    var id: EntityID { metadata.id }
}

struct MoneyTransaction: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var date: Date
    var title: String
    var kind: MoneyTransactionKind
    var amount: MoneyAmount
    var fromAccountID: EntityID? = nil
    var toAccountID: EntityID? = nil
    var category: MoneyTransactionCategory? = nil
    var balanceBefore: MoneyAmount? = nil
    var balanceAfter: MoneyAmount? = nil
    var notes: String? = nil

    var id: EntityID { metadata.id }

    var signedMinorUnits: Int {
        switch kind {
        case .income:
            amount.minorUnits
        case .expense:
            -amount.minorUnits
        case .transfer, .balanceAdjustment:
            0
        }
    }
}

enum AITextRegistrationConfirmationStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case rejected = "Rejected"

    var id: String { rawValue }
}

struct AITextRegistrationCandidate: Codable, Hashable {
    var title: String
    var kind: MoneyTransactionKind
    var amount: MoneyAmount
    var date: Date? = nil
    var fromAccountID: EntityID? = nil
    var toAccountID: EntityID? = nil
    var category: MoneyTransactionCategory? = nil
    var notes: String? = nil
}

struct AITextRegistrationConfirmation: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var originalText: String
    var candidate: AITextRegistrationCandidate
    var status: AITextRegistrationConfirmationStatus
    var confirmedTransactionID: EntityID? = nil

    var id: EntityID { metadata.id }
}
