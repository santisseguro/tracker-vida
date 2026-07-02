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

enum MoneyAccountColor: String, CaseIterable, Codable, Identifiable {
    case money
    case primary
    case health
    case university
    case warning
    case ai

    var id: String { rawValue }

    var label: String {
        switch self {
        case .money:
            return "Cyan"
        case .primary:
            return "Blue"
        case .health:
            return "Green"
        case .university:
            return "Red"
        case .warning:
            return "Orange"
        case .ai:
            return "Purple"
        }
    }
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
    var color: MoneyAccountColor
    var notes: String? = nil

    var id: EntityID { metadata.id }

    init(
        metadata: BaseMetadata,
        name: String,
        currency: CurrencyCode,
        currentBalance: MoneyAmount,
        kind: MoneyAccountKind,
        status: MoneyAccountStatus,
        color: MoneyAccountColor = .money,
        notes: String? = nil
    ) {
        self.metadata = metadata
        self.name = name
        self.currency = currency
        self.currentBalance = currentBalance
        self.kind = kind
        self.status = status
        self.color = color
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case metadata
        case name
        case currency
        case currentBalance
        case kind
        case status
        case color
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(BaseMetadata.self, forKey: .metadata)
        name = try container.decode(String.self, forKey: .name)
        currency = try container.decode(CurrencyCode.self, forKey: .currency)
        currentBalance = try container.decode(MoneyAmount.self, forKey: .currentBalance)
        kind = try container.decode(MoneyAccountKind.self, forKey: .kind)
        status = try container.decode(MoneyAccountStatus.self, forKey: .status)
        if container.contains(.color) {
            color = try container.decodeIfPresent(MoneyAccountColor.self, forKey: .color) ?? .money
        } else {
            color = Self.legacyDefaultColor(for: metadata.id)
        }
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(name, forKey: .name)
        try container.encode(currency, forKey: .currency)
        try container.encode(currentBalance, forKey: .currentBalance)
        try container.encode(kind, forKey: .kind)
        try container.encode(status, forKey: .status)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    private static func legacyDefaultColor(for id: EntityID) -> MoneyAccountColor {
        switch id.uuidString.uppercased() {
        case "00000000-0000-0000-0000-000000000201":
            return .warning
        case "00000000-0000-0000-0000-000000000202":
            return .primary
        case "00000000-0000-0000-0000-000000000203":
            return .health
        default:
            return .money
        }
    }
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
