export const APP_AREAS = [
  'dashboard',
  'gym-health',
  'university',
  'money',
  'settings',
  'daily-orders',
] as const;

export type AppArea = (typeof APP_AREAS)[number];

export const PRIORITY_LEVELS = ['low', 'medium', 'high', 'urgent'] as const;

export type PriorityLevel = (typeof PRIORITY_LEVELS)[number];

export const COMPLETION_STATUSES = [
  'pending',
  'in-progress',
  'done',
  'skipped',
] as const;

export type CompletionStatus = (typeof COMPLETION_STATUSES)[number];

export type EntityId = string;
export type ISODateString = string;
export type ISODateTimeString = string;
export const MONEY_CURRENCIES = ['ARS', 'USDT'] as const;

export type CurrencyCode = (typeof MONEY_CURRENCIES)[number];

export interface BaseEntity {
  id: EntityId;
  createdAt: ISODateTimeString;
  updatedAt: ISODateTimeString;
  archivedAt?: ISODateTimeString;
}

export interface ReminderLeadTime {
  amount: number;
  unit: 'minute' | 'hour' | 'day' | 'week';
}

export interface LinkedResource {
  label: string;
  url: string;
}

export function compareIsoDates(a: ISODateString, b: ISODateString) {
  return a.localeCompare(b);
}

export function isIsoDateOnOrBefore(
  date: ISODateString,
  referenceDate: ISODateString,
) {
  return compareIsoDates(date, referenceDate) <= 0;
}

export function daysBetweenIsoDates(
  startDate: ISODateString,
  endDate: ISODateString,
) {
  const start = Date.parse(`${startDate}T00:00:00.000Z`);
  const end = Date.parse(`${endDate}T00:00:00.000Z`);

  return Math.round((end - start) / 86_400_000);
}

export function sortByIsoDateAsc<T>(
  items: readonly T[],
  getDate: (item: T) => ISODateString | undefined,
) {
  return [...items].sort((a, b) => {
    const dateA = getDate(a);
    const dateB = getDate(b);

    if (!dateA && !dateB) {
      return 0;
    }

    if (!dateA) {
      return 1;
    }

    if (!dateB) {
      return -1;
    }

    return compareIsoDates(dateA, dateB);
  });
}
