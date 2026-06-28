import type {
  AppArea,
  BaseEntity,
  EntityId,
  ISODateString,
  ISODateTimeString,
  PriorityLevel,
} from './shared';

export const DAILY_ORDER_SOURCES = ['manual-draft', 'ai-generated'] as const;
export const DAILY_ORDER_STATUSES = [
  'pending',
  'in-progress',
  'done',
  'skipped',
] as const;
export const DAILY_ORDER_ITEM_KINDS = ['task', 'reminder', 'review'] as const;

export type DailyOrderSource = (typeof DAILY_ORDER_SOURCES)[number];
export type DailyOrderStatus = (typeof DAILY_ORDER_STATUSES)[number];
export type DailyOrderItemKind = (typeof DAILY_ORDER_ITEM_KINDS)[number];

export interface DailyChecklistItem {
  id: EntityId;
  title: string;
  kind: DailyOrderItemKind;
  area: AppArea;
  status: DailyOrderStatus;
  priority: PriorityLevel;
  sourceEntityId?: EntityId;
  rationale?: string;
}

export interface DailyOrder extends BaseEntity {
  title: string;
  area: AppArea;
  status: DailyOrderStatus;
  priority: PriorityLevel;
  checklist: DailyChecklistItem[];
  sourceEntityIds?: EntityId[];
}

export interface AIGeneratedDailyOrderPlan extends BaseEntity {
  area: 'daily-orders';
  date: ISODateString;
  source: DailyOrderSource;
  generatedAt?: ISODateTimeString;
  promptVersion?: string;
  summary?: string;
  orders: DailyOrder[];
}

export interface DailyOrderCompletionRatio {
  completed: number;
  total: number;
  ratio: number;
}

export function getDailyOrderCompletionRatio(
  plan: AIGeneratedDailyOrderPlan,
): DailyOrderCompletionRatio {
  const items = plan.orders.flatMap((order) => order.checklist);
  const total = items.length;
  const completed = items.filter(
    (item) => item.status === 'done' || item.status === 'skipped',
  ).length;

  return {
    completed,
    total,
    ratio: total === 0 ? 0 : completed / total,
  };
}

export function getOpenDailyChecklistItems(plan: AIGeneratedDailyOrderPlan) {
  return plan.orders
    .flatMap((order) => order.checklist)
    .filter(
      (item) => item.status === 'pending' || item.status === 'in-progress',
    );
}
