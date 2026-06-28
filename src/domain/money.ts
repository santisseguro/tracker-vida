import type {
  BaseEntity,
  CurrencyCode,
  EntityId,
  ISODateString,
} from './shared';

export const MONEY_TRANSACTION_TYPES = [
  'income',
  'expense',
  'transfer',
  'balance-adjustment',
] as const;
export const MONEY_ACCOUNT_STATUSES = ['active', 'archived'] as const;
export const MONEY_ACCOUNT_KINDS = [
  'cash',
  'bank',
  'digital-wallet',
  'crypto-wallet',
  'other',
] as const;
export const AI_TEXT_REGISTRATION_CONFIRMATION_STATUSES = [
  'pending',
  'confirmed',
  'rejected',
] as const;
export const INCOME_TRANSACTION_CATEGORIES = [
  'Trabajo',
  'Familia',
  'Venta',
  'Reembolso',
  'Otro',
] as const;
export const EXPENSE_TRANSACTION_CATEGORIES = [
  'Comida',
  'Transporte',
  'Universidad',
  'Ropa',
  'Tecnología',
  'Salud',
  'Suscripciones',
  'Salidas',
  'Otro',
] as const;

export type MoneyTransactionType = (typeof MONEY_TRANSACTION_TYPES)[number];
export type MoneyAccountStatus = (typeof MONEY_ACCOUNT_STATUSES)[number];
export type MoneyAccountKind = (typeof MONEY_ACCOUNT_KINDS)[number];
export type AITextRegistrationConfirmationStatus =
  (typeof AI_TEXT_REGISTRATION_CONFIRMATION_STATUSES)[number];
export type IncomeTransactionCategory =
  (typeof INCOME_TRANSACTION_CATEGORIES)[number];
export type ExpenseTransactionCategory =
  (typeof EXPENSE_TRANSACTION_CATEGORIES)[number];
export type MoneyTransactionCategory =
  IncomeTransactionCategory | ExpenseTransactionCategory;

export interface MoneyAmount {
  amountMinorUnits: number;
  currency: CurrencyCode;
}

export interface MoneyAccount extends BaseEntity {
  area: 'money';
  name: string;
  currency: CurrencyCode;
  kind: MoneyAccountKind;
  status: MoneyAccountStatus;
  notes?: string;
}

export interface AccountBalance extends BaseEntity {
  area: 'money';
  accountId: EntityId;
  balanceMinorUnits: number;
  currency: CurrencyCode;
  recordedOn: ISODateString;
  notes?: string;
}

interface BaseMoneyTransaction extends BaseEntity {
  area: 'money';
  date: ISODateString;
  title: string;
  amountMinorUnits: number;
  currency: CurrencyCode;
  fromAccountId?: EntityId;
  toAccountId?: EntityId;
  notes?: string;
}

export interface IncomeTransaction extends BaseMoneyTransaction {
  type: 'income';
  category: IncomeTransactionCategory;
}

export interface ExpenseTransaction extends BaseMoneyTransaction {
  type: 'expense';
  category: ExpenseTransactionCategory;
}

export interface TransferTransaction extends BaseMoneyTransaction {
  type: 'transfer';
  category?: never;
}

export interface BalanceAdjustmentTransaction extends BaseMoneyTransaction {
  type: 'balance-adjustment';
  category?: never;
}

export type MoneyTransaction =
  | IncomeTransaction
  | ExpenseTransaction
  | TransferTransaction
  | BalanceAdjustmentTransaction;

interface BaseAITextRegistrationCandidate {
  title: string;
  amount: MoneyAmount;
  date?: ISODateString;
  fromAccountId?: EntityId;
  toAccountId?: EntityId;
  notes?: string;
}

export type AITextRegistrationCandidate =
  | (BaseAITextRegistrationCandidate & {
      type: 'income';
      category: IncomeTransactionCategory;
    })
  | (BaseAITextRegistrationCandidate & {
      type: 'expense';
      category: ExpenseTransactionCategory;
    })
  | (BaseAITextRegistrationCandidate & {
      type: 'transfer' | 'balance-adjustment';
      category?: never;
    });

export interface AITextRegistrationConfirmation extends BaseEntity {
  area: 'money';
  originalText: string;
  candidate: AITextRegistrationCandidate;
  status: AITextRegistrationConfirmationStatus;
  confirmedTransactionId?: EntityId;
}

export function getSignedTransactionAmountMinorUnits(
  transaction: MoneyTransaction,
) {
  if (transaction.type === 'income') {
    return transaction.amountMinorUnits;
  }

  if (transaction.type === 'expense') {
    return -transaction.amountMinorUnits;
  }

  return 0;
}

export function sumSignedTransactionAmountsMinorUnits(
  transactions: readonly MoneyTransaction[],
) {
  return transactions.reduce(
    (total, transaction) =>
      total + getSignedTransactionAmountMinorUnits(transaction),
    0,
  );
}

export function isTransferTransaction(transaction: MoneyTransaction) {
  return transaction.type === 'transfer';
}

export function isBalanceAdjustmentTransaction(transaction: MoneyTransaction) {
  return transaction.type === 'balance-adjustment';
}
