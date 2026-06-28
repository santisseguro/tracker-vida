import { describe, expect, it } from 'vitest';

import {
  getAcademicTaskUrgency,
  getAverageSleepHours,
  getDailyOrderCompletionRatio,
  getGymAttendanceCount,
  getLatestWeightLog,
  getOpenDailyChecklistItems,
  getSignedTransactionAmountMinorUnits,
  EXPENSE_TRANSACTION_CATEGORIES,
  INCOME_TRANSACTION_CATEGORIES,
  isAcademicTaskOverdue,
  isBalanceAdjustmentTransaction,
  isLateEntry,
  isTransferTransaction,
  sortDashboardCards,
  sumSignedTransactionAmountsMinorUnits,
  type AcademicTask,
  type AIGeneratedDailyOrderPlan,
  type DashboardCard,
  type DailyHealthLog,
  type MoneyTransaction,
  type WeightLog,
} from '..';

const baseEntity = {
  id: 'entity-1',
  createdAt: '2026-06-28T12:00:00.000Z',
  updatedAt: '2026-06-28T12:00:00.000Z',
};

describe('gym health helpers', () => {
  it('detects late entries and finds the latest weight log', () => {
    const logs: WeightLog[] = [
      {
        ...baseEntity,
        id: 'weight-1',
        area: 'gym-health',
        date: '2026-06-27',
        weightKg: 82.5,
        source: { source: 'manual' },
      },
      {
        ...baseEntity,
        id: 'weight-2',
        area: 'gym-health',
        date: '2026-06-28',
        weightKg: 82.2,
        source: { source: 'manual' },
      },
    ];

    expect(isLateEntry('2026-06-27', '2026-06-28T10:00:00.000Z')).toBe(true);
    expect(getLatestWeightLog(logs)?.id).toBe('weight-2');
  });

  it('summarizes attendance and sleep from daily health logs', () => {
    const logs: DailyHealthLog[] = [
      {
        ...baseEntity,
        id: 'health-1',
        area: 'gym-health',
        date: '2026-06-27',
        totalCalories: 2400,
        gymAttended: true,
        workoutDurationMinutes: 60,
        workoutType: 'push',
        sleepHours: 7,
        sleepQuality: 'good',
        source: { source: 'manual' },
      },
      {
        ...baseEntity,
        id: 'health-2',
        area: 'gym-health',
        date: '2026-06-28',
        gymAttended: false,
        sleepHours: 8,
        sleepQuality: 'great',
        source: { source: 'manual' },
      },
    ];

    expect(getGymAttendanceCount(logs)).toBe(1);
    expect(getAverageSleepHours(logs)).toBe(7.5);
  });
});

describe('university helpers', () => {
  const task: AcademicTask = {
    ...baseEntity,
    area: 'university',
    title: 'Submit assignment',
    type: 'assignment',
    status: 'pending',
    priority: 'high',
    dueDate: '2026-06-27',
  };

  it('detects overdue academic tasks', () => {
    expect(isAcademicTaskOverdue(task, '2026-06-28')).toBe(true);
    expect(getAcademicTaskUrgency(task, '2026-06-28')).toBe('overdue');
  });
});

describe('money helpers', () => {
  const income: MoneyTransaction = {
    ...baseEntity,
    area: 'money',
    date: '2026-06-28',
    title: 'Income',
    type: 'income',
    amountMinorUnits: 100_000,
    currency: 'ARS',
    category: 'Trabajo',
  };

  const expense: MoneyTransaction = {
    ...baseEntity,
    id: 'entity-2',
    area: 'money',
    date: '2026-06-28',
    title: 'Expense',
    type: 'expense',
    amountMinorUnits: 25_000,
    currency: 'ARS',
    category: 'Comida',
  };

  it('exposes simple category labels for income and expense transactions only', () => {
    expect(INCOME_TRANSACTION_CATEGORIES).toEqual([
      'Trabajo',
      'Familia',
      'Venta',
      'Reembolso',
      'Otro',
    ]);
    expect(EXPENSE_TRANSACTION_CATEGORIES).toEqual([
      'Comida',
      'Transporte',
      'Universidad',
      'Ropa',
      'Tecnología',
      'Salud',
      'Suscripciones',
      'Salidas',
      'Otro',
    ]);
    expect(income.category).toBe('Trabajo');
    expect(expense.category).toBe('Comida');
  });

  it('normalizes signed transaction amounts', () => {
    expect(getSignedTransactionAmountMinorUnits(income)).toBe(100_000);
    expect(getSignedTransactionAmountMinorUnits(expense)).toBe(-25_000);
    expect(sumSignedTransactionAmountsMinorUnits([income, expense])).toBe(
      75_000,
    );
  });

  it('identifies transfer and balance adjustment entries', () => {
    const transfer: MoneyTransaction = {
      ...baseEntity,
      id: 'entity-3',
      area: 'money',
      date: '2026-06-28',
      title: 'Move to USDT',
      type: 'transfer',
      amountMinorUnits: 10_000,
      currency: 'USDT',
      fromAccountId: 'account-ars',
      toAccountId: 'account-usdt',
    };
    const adjustment: MoneyTransaction = {
      ...baseEntity,
      id: 'entity-4',
      area: 'money',
      date: '2026-06-28',
      title: 'Correct balance',
      type: 'balance-adjustment',
      amountMinorUnits: 5_000,
      currency: 'ARS',
      toAccountId: 'account-ars',
    };

    expect(isTransferTransaction(transfer)).toBe(true);
    expect(isBalanceAdjustmentTransaction(adjustment)).toBe(true);
    expect('category' in transfer).toBe(false);
    expect('category' in adjustment).toBe(false);
  });
});

describe('dashboard helpers', () => {
  it('orders attention cards before normal cards', () => {
    const cards: DashboardCard[] = [
      {
        ...baseEntity,
        id: 'card-1',
        area: 'dashboard',
        kind: 'summary',
        status: 'normal',
        title: 'Normal',
        priority: 'low',
        sortOrder: 1,
      },
      {
        ...baseEntity,
        id: 'card-2',
        area: 'university',
        kind: 'reminder',
        status: 'urgent',
        title: 'Urgent',
        priority: 'urgent',
        sortOrder: 2,
      },
    ];

    expect(sortDashboardCards(cards).map((card) => card.id)).toEqual([
      'card-2',
      'card-1',
    ]);
  });
});

describe('daily order helpers', () => {
  const plan: AIGeneratedDailyOrderPlan = {
    ...baseEntity,
    area: 'daily-orders',
    date: '2026-06-28',
    source: 'manual-draft',
    orders: [
      {
        ...baseEntity,
        id: 'order-1',
        title: 'Start the day',
        area: 'dashboard',
        status: 'in-progress',
        priority: 'high',
        checklist: [
          {
            id: 'item-1',
            title: 'Review deadlines',
            kind: 'review',
            area: 'university',
            status: 'done',
            priority: 'high',
          },
          {
            id: 'item-2',
            title: 'Log expenses',
            kind: 'task',
            area: 'money',
            status: 'pending',
            priority: 'medium',
          },
        ],
      },
    ],
  };

  it('calculates completion ratio and returns open checklist items', () => {
    expect(getDailyOrderCompletionRatio(plan)).toEqual({
      completed: 1,
      total: 2,
      ratio: 0.5,
    });
    expect(getOpenDailyChecklistItems(plan).map((item) => item.id)).toEqual([
      'item-2',
    ]);
  });
});
