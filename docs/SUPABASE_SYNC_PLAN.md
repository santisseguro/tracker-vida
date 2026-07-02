# Supabase Sync Plan

## Purpose

This document plans a future Supabase sync layer for Tracker Vida before any Supabase SDK, network calls, or persistence changes are added.

The current app is local-first and stores one `PersistedAppState` JSON file containing:

- `weightGoal`
- `weightLogs`
- `dailyHealthLogs`
- `dailyOrderPlan`
- `criticalTasks`
- `upcomingDeadlines`
- `waitingResponses`
- `timeline`
- `moneyAccounts`
- `moneyTransactions`

The Supabase model should preserve that local-first behavior. Cloud sync should be a backup and restore path for one private app owner, not a multi-user collaboration system.

## Design Principles

- Keep the existing Swift models as the source of truth for v1 shape.
- Sync row-level entities instead of uploading one large JSON blob.
- Keep deterministic `UUID` values from `BaseMetadata.id` as Supabase primary keys.
- Keep `created_at`, `updated_at`, and `archived_at` on each synced row.
- Prefer simple last-write-wins conflict handling for v1.
- Do not sync derived dashboard values or calculation outputs.
- Do not add v1 scope creep such as budgets, recurring payment automation, or HealthKit import sync.

## Shared Row Conventions

Most tables should include:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | Maps to `BaseMetadata.id`. |
| `owner_id` | `uuid not null` | References `app_owner.id` or Supabase auth user id. |
| `created_at` | `timestamptz not null` | Maps to `BaseMetadata.createdAt`. |
| `updated_at` | `timestamptz not null` | Maps to `BaseMetadata.updatedAt`; used for conflict resolution. |
| `archived_at` | `timestamptz` | Maps to `BaseMetadata.archivedAt`; used for soft deletes where needed. |

Use snake_case in Supabase and map to Swift camelCase at the repository boundary.

## Proposed Tables

### `app_owner`

Stores the single private app owner profile and anchors row-level security.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | Prefer matching Supabase `auth.users.id` once auth exists. |
| `display_name` | `text` | Optional local display name. |
| `timezone_identifier` | `text not null` | Example: `America/Argentina/Buenos_Aires`. |
| `schema_version` | `integer not null default 1` | Current cloud schema version. |
| `created_at` | `timestamptz not null` | Owner row creation time. |
| `updated_at` | `timestamptz not null` | Owner row update time. |

### `health_weight_goals`

Stores weight goal and health calculation configuration.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `WeightGoal.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `target_weight_kg` | `numeric not null` | `WeightGoal.targetWeightKg`. |
| `start_weight_kg` | `numeric` | Optional. |
| `start_date` | `date not null` | `WeightGoal.startDate`. |
| `target_date` | `date` | Optional. |
| `gym_day_calorie_target` | `integer not null` | `WeightGoal.gymDayCalorieTarget`. |
| `rest_day_calorie_target` | `integer not null` | `WeightGoal.restDayCalorieTarget`. |
| `target_workouts_per_week` | `integer not null` | `WeightGoal.targetWorkoutsPerWeek`. |
| `ideal_gym_weekdays` | `integer[] not null` | Swift weekday values, currently `[2, 3, 4, 5, 6]`. |
| `is_active` | `boolean not null` | Current active goal flag. |
| `notes` | `text` | Optional. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

### `health_weight_logs`

Stores body weight entries.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `WeightLog.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `log_date` | `date not null` | `WeightLog.date`, compared by day. |
| `weight_kg` | `numeric not null` | `WeightLog.weightKg`. |
| `source` | `text not null` | `Manual` or future `Apple Health`. |
| `source_imported_at` | `timestamptz` | Future import metadata. |
| `source_external_id` | `text` | Future import metadata. |
| `source_device_name` | `text` | Future import metadata. |
| `is_late_entry` | `boolean not null default false` | From `LateEntryMetadata`. |
| `original_entry_date` | `date` | From `LateEntryMetadata.originalEntryDate`. |
| `entered_at` | `timestamptz` | From `LateEntryMetadata.enteredAt`. |
| `late_entry_reason` | `text` | Optional. |
| `notes` | `text` | Optional. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

Recommended constraint: unique `(owner_id, log_date)` for active rows, matching the current local upsert-by-date workflow.

### `health_daily_logs`

Stores the daily Gym / Health v1 entry.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `DailyHealthLog.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `log_date` | `date not null` | `DailyHealthLog.date`, compared by day. |
| `total_calories` | `integer` | Optional daily total. |
| `gym_attended` | `boolean not null` | Yes/no attendance. |
| `workout_duration_minutes` | `integer` | Present only when `gym_attended` is true. |
| `workout_type` | `text` | `Push`, `Pull`, `Legs`, `Full Body`, `Cardio`, `Other`. |
| `sleep_hours` | `numeric` | Optional. |
| `sleep_quality` | `text` | `Good`, `Normal`, `Bad`. |
| `source` | `text not null` | `Manual` or future `Apple Health`. |
| `source_imported_at` | `timestamptz` | Future import metadata. |
| `source_external_id` | `text` | Future import metadata. |
| `source_device_name` | `text` | Future import metadata. |
| `is_late_entry` | `boolean not null default false` | From `LateEntryMetadata`. |
| `original_entry_date` | `date` | From `LateEntryMetadata.originalEntryDate`. |
| `entered_at` | `timestamptz` | From `LateEntryMetadata.enteredAt`. |
| `late_entry_reason` | `text` | Optional. |
| `notes` | `text` | Optional. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

Recommended constraint: unique `(owner_id, log_date)` for active rows.

### `university_tasks`

Stores local university tasks. The current app separates critical tasks and upcoming deadlines in memory, but Supabase should use one table and derive those groups from priority/status.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `AcademicTask.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `course_id` | `uuid` | Optional; keep null until courses are implemented. |
| `title` | `text not null` | Task title. |
| `category` | `text not null` | `Académico`, `Trámite`, `Documento`, `Deadline`, `Email`, `Otro`. |
| `status` | `text not null` | `Pendiente`, `En progreso`, `Esperando respuesta`, `Completada`. |
| `priority` | `text not null` | `Crítica`, `Alta`, `Media`, `Baja`. |
| `due_date` | `date` | Optional deadline. |
| `waiting_since` | `date` | Required in app logic when status is `Esperando respuesta`. |
| `completed_at` | `timestamptz` | Set when status is `Completada`. |
| `notes` | `text` | Optional. |
| `links` | `jsonb not null default '[]'` | Current `[LinkedResource]`; keep simple until links need their own table. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

### `money_accounts`

Stores accounts and current balances.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `MoneyAccount.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `name` | `text not null` | Account name. |
| `currency` | `text not null` | `ARS` or `USDT`. |
| `current_balance_minor_units` | `integer not null` | `MoneyAccount.currentBalance.minorUnits`. |
| `kind` | `text not null` | `Cash`, `Bank`, `Digital Wallet`, `Crypto Wallet`, `Other`. |
| `status` | `text not null` | `Active` or `Archived`. |
| `notes` | `text` | Optional. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

Account balances remain local-first and manually maintained. They should be updated by app workflows when transactions sync or when a balance adjustment is applied.

### `money_transactions`

Stores income, expense, transfer, and balance adjustment rows.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `MoneyTransaction.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `transaction_date` | `date not null` | `MoneyTransaction.date`. |
| `title` | `text not null` | Transaction title. |
| `kind` | `text not null` | `Income`, `Expense`, `Transfer`, `Balance Adjustment`. |
| `amount_minor_units` | `integer not null` | Stored amount. For balance adjustments this is the difference. |
| `amount_currency` | `text not null` | `ARS` or `USDT`. |
| `from_account_id` | `uuid` | Required for expense and transfer source. |
| `to_account_id` | `uuid` | Required for income and transfer destination. |
| `category_kind` | `text` | `income` or `expense`; null for transfers and adjustments. |
| `category_label` | `text` | Income/expense category label only. |
| `balance_before_minor_units` | `integer` | Balance adjustment support. |
| `balance_before_currency` | `text` | Balance adjustment support. |
| `balance_after_minor_units` | `integer` | Balance adjustment support. |
| `balance_after_currency` | `text` | Balance adjustment support. |
| `notes` | `text` | Optional. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

Rules to preserve:

- Income has `to_account_id` and an income category.
- Expense has `from_account_id` and an expense category.
- Transfer has both account IDs and no category.
- Balance adjustment has before/after values and no category.
- `Suscripciones` remains only an expense category label, not recurring payment logic.

### `daily_order_plans`

Stores the generated daily order plan header.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `AIGeneratedDailyOrderPlan.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `plan_date` | `date not null` | `AIGeneratedDailyOrderPlan.date`. |
| `source` | `text not null` | `Manual Draft` or `AI Generated`. Current generator is local rule-based. |
| `generated_at` | `timestamptz` | Generation timestamp. |
| `prompt_version` | `text` | Current value like `local-rule-v1`. |
| `summary` | `text` | Generated explanation. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

Recommended constraint: unique `(owner_id, plan_date)` for active rows.

### `daily_orders`

Stores each order inside a plan.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `DailyOrder.metadata.id`. |
| `owner_id` | `uuid not null` | App owner. |
| `plan_id` | `uuid not null` | References `daily_order_plans.id`. |
| `title` | `text not null` | Order title. |
| `area` | `text not null` | Current v1 uses `gymHealth`. |
| `status` | `text not null` | `Pending`, `In Progress`, `Done`, `Skipped`. |
| `priority` | `text not null` | `low`, `medium`, `high`, `urgent`. |
| `source_entity_ids` | `uuid[] not null default '{}'` | Source IDs, currently often empty. |
| `created_at` | `timestamptz not null` | Metadata. |
| `updated_at` | `timestamptz not null` | Metadata. |
| `archived_at` | `timestamptz` | Metadata. |

### `daily_checklist_items`

Stores checklist state so toggles persist across devices/reinstalls.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid primary key` | `DailyChecklistItem.id`; generated deterministically for rule-based items. |
| `owner_id` | `uuid not null` | App owner. |
| `order_id` | `uuid not null` | References `daily_orders.id`. |
| `title` | `text not null` | Checklist item title. |
| `kind` | `text not null` | `Task`, `Reminder`, `Review`. |
| `area` | `text not null` | Current v1 uses `gymHealth`. |
| `status` | `text not null` | `Pending`, `In Progress`, `Done`, `Skipped`. |
| `priority` | `text not null` | `low`, `medium`, `high`, `urgent`. |
| `source_entity_id` | `uuid` | Optional source link. |
| `rationale` | `text` | Optional generated rationale. |
| `created_at` | `timestamptz not null` | Use inserted/synced time if no local field exists. |
| `updated_at` | `timestamptz not null` | Use checklist status update time. |
| `archived_at` | `timestamptz` | Soft delete when a generated item is no longer active. |

## Local JSON To Supabase Mapping

| Local JSON field | Supabase target |
| --- | --- |
| `schemaVersion` | `app_owner.schema_version` and app migration logic. |
| `weightGoal` | One active row in `health_weight_goals`. |
| `weightLogs[]` | Rows in `health_weight_logs`. |
| `dailyHealthLogs[]` | Rows in `health_daily_logs`. |
| `dailyOrderPlan` | `daily_order_plans`, `daily_orders`, `daily_checklist_items`. |
| `criticalTasks[]` | Rows in `university_tasks` with `priority = 'Crítica'`. |
| `upcomingDeadlines[]` | Rows in `university_tasks` with non-critical priorities. |
| `waitingResponses[]` | Local-only derived/static list for now. |
| `timeline[]` | Local-only static preview for now. |
| `moneyAccounts[]` | Rows in `money_accounts`. |
| `moneyTransactions[]` | Rows in `money_transactions`. |

The repository layer should convert one `PersistedAppState` into row upserts and convert fetched rows back into the same local `PersistedAppState` shape. This keeps `AppStore` mostly unchanged during the first sync implementation.

## Sync Strategy For A Single-User App

1. Keep JSON file persistence as the offline source of truth.
2. Add a cloud repository that can load and save the same state shape through Supabase rows.
3. On app launch:
   - Load local JSON immediately.
   - Start a background cloud pull if the user is signed in.
   - Merge cloud rows into local state.
   - Save merged state back to local JSON.
4. After local mutations:
   - Save local JSON first.
   - Queue row-level upserts for changed entities.
   - Push queued changes when network/auth is available.
5. Track a lightweight `last_successful_sync_at` locally, not as a user-facing feature.
6. Avoid realtime subscriptions for v1. Manual/background pull-push is enough for a personal single-user app.

## Conflict Strategy

Use row-level last-write-wins for v1:

- If local `updatedAt` is newer than cloud `updated_at`, push local row.
- If cloud `updated_at` is newer than local `updatedAt`, accept cloud row.
- If timestamps match, keep local row and do nothing.
- If either side has `archived_at`, the newest `updated_at` decides whether the row is active or archived.

Special cases:

- Health logs and daily logs should also respect unique `(owner_id, log_date)`. If two rows exist for the same date, keep the row with newer `updated_at` and archive the older duplicate.
- Daily checklist items use deterministic IDs when generated. Preserve existing item status if the generator produces the same item again.
- Money transactions should be treated as append-first records. Editing or deleting transactions later should be deliberate because account balances depend on them.
- If money account balances differ after transaction sync, prefer the explicit `money_accounts.current_balance_minor_units` for v1 and log the mismatch for future diagnostics.

This is intentionally simple because there is one app owner and no collaborative editing.

## Local-Only For Now

Keep these out of Supabase in the first implementation:

- Dashboard view state and summaries.
- `GymHealthProgress` calculation results.
- Weekly calorie/gym derived metrics.
- Mock/static ARS/USDT exchange rate.
- Settings placeholder sections.
- Static `waitingResponses` and `timeline` preview items until they become real v1 data.
- Raw AI prompts, external AI responses, or model metadata.
- HealthKit/Apple Health raw samples or permissions.
- Local debug logs, build artifacts, and screenshots.

## Security Assumptions

- The app is private and personal, but data is still sensitive.
- Supabase authentication should be required before any cloud sync.
- Row Level Security should be enabled on every table.
- RLS policy should only allow the authenticated owner to select, insert, update, or archive rows where `owner_id = auth.uid()`.
- Do not use public anonymous read access for any app data table.
- Keep service role keys out of the iOS app.
- Store only the public anon key in the app when Supabase is added.
- Do not add telemetry or analytics as part of sync.
- Money and health data should not be sent to AI services as part of this sync work.

## Step-By-Step Implementation Plan

1. Create SQL migrations for the proposed tables, constraints, indexes, and RLS policies.
2. Add a small Swift mapping layer that converts between current models and Supabase DTOs.
3. Add Supabase configuration placeholders without making network calls by default.
4. Add a `CloudAppStateRepository` protocol that mirrors `AppStatePersisting` concepts but works with rows.
5. Implement a dry-run mapper test that converts local `PersistedAppState` to cloud row DTOs and back.
6. Add authenticated pull-only restore behind a development flag.
7. Add push-only row upserts after local JSON save succeeds.
8. Add merge tests for newer local row, newer cloud row, archived row, and duplicate same-day health logs.
9. Add a manual sync trigger for development and keep automatic sync conservative.
10. Once stable, enable launch-time pull and mutation-time queued push.

## First Safe Coding Task

The safest next implementation task is to add Swift DTOs and pure mapping tests only. That can validate the table shape against the existing models without adding the Supabase SDK, changing persistence behavior, or introducing network risk.
