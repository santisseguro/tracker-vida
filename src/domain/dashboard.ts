import type {
  AppArea,
  BaseEntity,
  EntityId,
  ISODateString,
  PriorityLevel,
} from './shared';

export const DASHBOARD_CARD_KINDS = [
  'summary',
  'reminder',
  'progress',
  'empty-state',
] as const;
export const DASHBOARD_CARD_STATUSES = [
  'normal',
  'attention',
  'urgent',
  'complete',
] as const;

export type DashboardCardKind = (typeof DASHBOARD_CARD_KINDS)[number];
export type DashboardCardStatus = (typeof DASHBOARD_CARD_STATUSES)[number];

export interface DashboardCard extends BaseEntity {
  area: AppArea;
  kind: DashboardCardKind;
  status: DashboardCardStatus;
  title: string;
  description?: string;
  priority: PriorityLevel;
  sortOrder: number;
  targetDate?: ISODateString;
  actionRoute?: string;
  sourceEntityId?: EntityId;
}

export interface DashboardSnapshot {
  date: ISODateString;
  cards: DashboardCard[];
}

const DASHBOARD_STATUS_WEIGHT: Record<DashboardCardStatus, number> = {
  urgent: 0,
  attention: 1,
  normal: 2,
  complete: 3,
};

export function sortDashboardCards(cards: readonly DashboardCard[]) {
  return [...cards].sort((a, b) => {
    const statusDifference =
      DASHBOARD_STATUS_WEIGHT[a.status] - DASHBOARD_STATUS_WEIGHT[b.status];

    if (statusDifference !== 0) {
      return statusDifference;
    }

    return a.sortOrder - b.sortOrder;
  });
}
