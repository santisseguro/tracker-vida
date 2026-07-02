# AI Assistant Architecture

## Purpose

Tracker Vida's AI bars should evolve from simple command capture into contextual assistants for the four main user-facing sections:

- Dashboard
- Gym / Health
- University
- Money

The assistant must support two different modes:

1. Answer read-only questions by analyzing local app state.
2. Perform local actions when appropriate, with confirmation or follow-up when needed.

The first implementation should stay local-first. Real AI providers, Supabase sync, HealthKit, notifications, and external integrations should remain out of this plan until explicitly implemented later.

## Core Principles

- `AppStore` remains the source of truth for all app data.
- Assistant output should never mutate data directly from a view.
- Read-only answers should use derived state, calculators, and local models.
- Actions should call existing `AppStore` workflows so persistence, dashboard summaries, charts, and screens update normally.
- Ambiguous or destructive actions require follow-up or confirmation.
- Local deterministic logic should remain available for fast, private, high-confidence commands.
- Real AI should later produce structured intents/tool calls, not free-form mutations.

## Read-Only Questions vs Actions

### Read-Only Questions

Read-only questions inspect current local state and return an answer without changing data.

Examples:

- "What classes do I have tomorrow?"
- "Am I on track?"
- "How much money do I have?"
- "What is urgent today?"

Read-only requests should:

- Build an `AssistantContextSnapshot` from `AppStore`.
- Route to a section-specific answer engine or real AI model.
- Return a concise assistant response.
- Avoid confirmation because no data changes.
- Never save state unless chat history persistence is explicitly added later.

### Actions

Actions create or update local data through existing workflows.

Examples:

- Add a university task.
- Log calories.
- Register an expense.
- Mark a task completed.

Actions should:

- Parse into a typed intent.
- Validate required fields.
- Ask follow-up questions for missing information.
- Ask confirmation when the action is ambiguous, destructive, or creates new records.
- Execute only through `AppStore`.
- Return a clear result after mutation.

## Assistant Request Flow

Recommended shared flow:

1. User submits text or speech from `AICommandBar`.
2. The section creates an `AssistantRequest` with:
   - section context
   - raw text
   - current date
   - optional pending conversation state
3. `AssistantCoordinator` classifies the request:
   - read-only question
   - action intent
   - follow-up reply
   - unsupported/unclear input
4. The section engine produces an `AssistantTurnResult`:
   - assistant message
   - optional pending follow-up state
   - optional proposed action
   - optional completed action summary
5. If an action is confirmed and valid, the engine calls `AppStore`.
6. SwiftUI renders the latest assistant response inside the same compact AI command card.

## Shared Types To Add Later

These types should be introduced in small steps when implementing the architecture:

```swift
enum AssistantSection {
    case dashboard
    case gymHealth
    case university
    case money
}

enum AssistantIntentKind {
    case question
    case action
    case followUp
    case unknown
}

struct AssistantRequest {
    var section: AssistantSection
    var text: String
    var date: Date
}

struct AssistantTurnResult {
    var response: String
    var requiresFollowUp: Bool
    var completedActionSummary: String?
}
```

Keep these separate from provider-specific DTOs. Gemini/OpenAI adapters should map into these app-owned types.

## Context Passed By Section

Only pass the minimum local state needed for the current section. Do not send raw persisted JSON wholesale to a future AI provider.

### Dashboard Context

Use:

- `DashboardViewState`
- `DailyOrdersViewState`
- current date
- active critical university tasks
- upcoming deadlines
- latest health summary
- latest generated health order
- money totals and active account summaries

Answers should support:

- "What should I do today?"
- "What is urgent?"
- "What changed across health, university, and money?"

Dashboard should not own mutations directly. If an action belongs to a section, route it to that section's action engine.

### Gym / Health Context

Use:

- `GymHealthViewState`
- `GymHealthProgress`
- `WeightGoal`
- recent `WeightLog` values
- recent `DailyHealthLog` values
- current `AIGeneratedDailyOrderPlan`

Answers should support:

- "Am I on track?"
- "What happens if I skip gym today?"
- "How many calories do I have left?"
- "Why did I get this order?"

Health answers should rely on deterministic calculations from `GymHealthEngine` and `GymHealthDailyOrderGenerator` where possible.

### University Context

Use:

- `UniversityViewState`
- active critical tasks
- upcoming deadlines
- waiting responses
- timeline items
- university classes
- schedule sessions
- computed today/upcoming classes
- current date and calendar

Answers should support:

- "What classes do I have tomorrow?"
- "What should I prioritize today?"
- "What deadlines are coming up?"
- "What tasks are waiting for response?"

University actions should support adding/editing tasks and classes only when the relevant local workflows exist.

### Money Context

Use:

- `MoneyViewState`
- active accounts
- recent transactions
- account balances
- money totals
- chart/trend calculator inputs
- current local mock exchange rate

Answers should support:

- "How much money do I have?"
- "Where did I spend most this week?"
- "Why did my balance change?"

Money actions should continue to use existing local transaction workflows.

## Local Tools And Actions By Section

### Dashboard Tools

Read-only:

- Summarize daily priorities.
- Summarize urgent tasks.
- Summarize health track status.
- Summarize money totals.
- Explain cross-section changes from local state.

Actions:

- Route to Gym / Health, University, or Money action engines.
- Mark university task completed only if the user clearly identifies the task.
- Toggle daily checklist item only if the user clearly identifies the item.

Confirmation:

- Required before marking tasks/checklist items complete from Dashboard.
- Required when multiple matching items exist.

### Gym / Health Tools

Read-only:

- Explain current track status.
- Explain daily order.
- Calculate calories left.
- Estimate impact of skipping gym using existing deterministic assumptions.
- Summarize weekly gym progress.
- Summarize weight trend.

Actions:

- Add/update today's weight log.
- Add/update today's total calories.
- Add/update today's gym attendance.
- Add/update today's sleep log.
- Toggle daily order checklist item.

Confirmation:

- Required before overwriting an existing previous-date entry.
- Required if the user asks to mark a daily order item done but the item match is ambiguous.
- Not required for clear same-day logging commands with exact values.

### University Tools

Read-only:

- List today's or tomorrow's classes.
- List upcoming classes this week.
- List critical tasks.
- List upcoming deadlines.
- List waiting-response tasks.
- Suggest today's priority order from local task status, priority, due date, and class schedule.

Actions:

- Add a university task.
- Edit a university task.
- Mark a task completed.
- Change task status or priority.
- Add a class.
- Add a schedule session.

Confirmation:

- Required before creating a class if the name looks similar to an existing class.
- Required before marking a task completed if multiple tasks match.
- Required before changing status or priority.
- Follow-up required when due date, class, task title, or status is missing.

### Money Tools

Read-only:

- Report total ARS and USDT.
- Explain account balances.
- Summarize spending by category over a period.
- Explain recent balance changes from transaction history.
- Summarize transfers and balance adjustments.

Actions:

- Add account.
- Edit account.
- Add income.
- Add expense.
- Add transfer.
- Add balance adjustment.

Confirmation:

- Required before creating a new account.
- Required before balance adjustments.
- Required for transfers when account or currency conversion is unclear.
- Follow-up required when origin/destination account is missing.
- Not required for high-confidence income/expense commands using existing accounts, amount, currency, and category, unless the user preference changes.

## Follow-Up Questions

Follow-up state should be explicit and typed. Avoid relying only on the previous assistant message text.

Each pending action should store:

- original user text
- parsed intent
- missing fields
- proposed values
- section
- current step
- creation date

Examples:

- Money: unknown account -> ask whether to create it -> ask initial balance -> complete pending expense.
- University: missing deadline date -> ask for date -> confirm task creation.
- Health: "log gym" without duration/type -> ask duration/type or use explicit defaults only if approved later.

Follow-up replies should be routed before parsing as a fresh command. If the pending flow is cancelled, clear pending state and return a short cancellation response.

## Existing MoneyConversationEngine

`MoneyConversationEngine` is the current temporary implementation of this architecture for Money.

It already provides:

- local deterministic parsing through `MoneyCommandParser`
- compact conversation state
- pending money command state
- unknown account creation follow-up
- initial balance prompt
- execution through `AppStore`
- inline latest assistant response in `AICommandBar`

Keep it for now as the Money-specific local engine.

Short-term improvements should:

- Rename or wrap it behind a more general `AssistantCoordinator` interface.
- Keep the deterministic parser as a local fallback.
- Add read-only Money question handling before falling back to movement parsing.
- Keep all balance mutations inside existing `AppStore` methods.

Do not turn `MoneyConversationEngine` into a broad all-section engine. Instead, use it as the first section-specific engine pattern.

## Replacing Local Parsing With Real AI Later

Real AI should not directly mutate app state. Gemini or OpenAI should produce structured outputs that map to app-owned intents.

Recommended future provider contract:

```json
{
  "intent_kind": "question",
  "section": "money",
  "answer_style": "direct",
  "tool_call": null,
  "needs_confirmation": false
}
```

For actions:

```json
{
  "intent_kind": "action",
  "section": "money",
  "tool_call": {
    "name": "add_expense",
    "arguments": {
      "amount": 12000,
      "currency": "ARS",
      "from_account_name": "Banco ARS",
      "category": "Comida",
      "note": "Parsed from user command"
    }
  },
  "needs_confirmation": false,
  "missing_fields": []
}
```

Provider adapter responsibilities:

- Build compact context from local state.
- Send only relevant section context.
- Decode structured output.
- Validate against local enums and known IDs.
- Convert provider output into `AssistantIntent`.
- Never call `AppStore` directly.

App responsibilities:

- Decide whether confirmation is required.
- Resolve names to local IDs.
- Ask follow-up questions.
- Execute confirmed tool calls through `AppStore`.
- Generate final success/error response.

## AppStore As Source Of Truth

All completed actions must use existing or future `AppStore` workflows:

- Health logs through health upsert methods.
- University tasks/classes through University methods.
- Money movements through Money transaction methods.
- Daily checklist toggles through checklist methods.

The assistant should not:

- mutate arrays directly from views
- edit persisted JSON directly
- write chart/dashboard values directly
- store derived values as canonical data

After an `AppStore` mutation, SwiftUI recomputes:

- section view state
- Dashboard summaries
- Money totals
- chart inputs
- Gym / Health progress
- daily order state where refresh logic applies

This keeps the assistant, manual forms, dashboard, charts, and persistence consistent.

## Charts And Dashboard Updates

Charts and Dashboard should update automatically when AI actions call existing workflows.

Examples:

- Money expense -> `addExpenseTransaction` updates account balance and transactions -> Dashboard money totals and Money chart inputs change.
- Health calories -> `upsertDailyHealthLog` updates daily log -> Gym progress and Dashboard calories change.
- University task completion -> `markAcademicTaskCompleted` updates task status -> Dashboard critical count changes.

If a future AI action mutates data and a chart does not update, the fix should be in shared state/calculation wiring, not in the assistant layer.

## Local/Rule-Based vs Real AI

### Keep Local Or Rule-Based

- Gym / Health calculations.
- Gym / Health daily order generator safety rules.
- Money balance math.
- Money chart calculations.
- University date/schedule calculations.
- Required-field validation.
- Confirmation rules.
- Conflict checks and duplicate checks.
- Persistence and AppStore mutations.

### Use Real AI Later

- Natural language understanding beyond simple commands.
- Cross-section summaries with nuanced phrasing.
- Explaining patterns in spending, health, or academic load.
- Turning messy user input into structured intents.
- Asking natural follow-up questions.
- Ranking priorities when several valid factors matter.

Real AI should explain and propose. Local code should validate and execute.

## Safety And Privacy

- Default to local-only processing until the user explicitly enables real AI.
- Keep private personal data out of external services unless the user opts in.
- Minimize context sent to a provider.
- Avoid medical, legal, or financial advice beyond local tracking summaries.
- For health, avoid unsafe instructions; frame answers around logged data and existing targets.
- For money, avoid investment/tax advice.
- For university, avoid essay generation or academic dishonesty workflows.

## Step-By-Step Implementation Plan

### Step 1: Shared Assistant Types

Add shared request/result/pending intent models without changing UI behavior.

Deliverables:

- `AssistantRequest`
- `AssistantTurnResult`
- `AssistantIntent`
- `PendingAssistantAction`
- tests for routing and pending state

### Step 2: Dashboard Read-Only Assistant

Replace generic captured-command confirmation with local read-only answers for:

- "What should I do today?"
- "What is urgent?"
- "What changed?"

No actions yet except existing explicit UI controls.

### Step 3: University Read-Only Assistant

Add local answers for:

- classes today/tomorrow
- upcoming classes this week
- critical tasks
- upcoming deadlines
- waiting responses
- suggested priority order

Keep task/class creation manual for this step.

### Step 4: Health Read-Only Assistant

Add local answers for:

- track status
- calories left
- skipped-gym impact
- daily order explanation
- sleep or weight trend summary

Use `GymHealthEngine` and `GymHealthDailyOrderGenerator`.

### Step 5: Generalize MoneyConversationEngine Interface

Wrap current Money conversation behavior behind a section assistant protocol, while preserving existing behavior.

Add read-only Money answers before transaction parsing:

- total money
- spending by category
- recent balance changes

### Step 6: University Actions

Add conversational local actions for:

- add task
- mark completed
- change status
- add class/session

Require confirmation or follow-up for ambiguous matches.

### Step 7: Health Actions

Add conversational local actions for:

- log weight
- log calories
- log gym
- log sleep
- toggle checklist item

Use confirmation for previous-date edits and ambiguous checklist matches.

### Step 8: Provider Adapter Boundary

Add a provider-neutral interface, but keep it disabled by default:

- `AssistantProvider`
- `LocalAssistantProvider`
- future `OpenAIAssistantProvider` or `GeminiAssistantProvider`

The app should continue using local engines until real API configuration is explicitly added.

### Step 9: Structured Outputs / Function Calling

When real AI is introduced:

- Send compact section context.
- Request strict structured output.
- Validate all fields locally.
- Convert tool calls to app-owned intents.
- Preserve existing confirmation rules.

### Step 10: Optional Chat History

Only after assistant behavior is useful, decide whether to persist recent assistant turns.

Default recommendation:

- keep only latest inline response per section
- persist pending actions only if needed to survive app restart
- do not store full chat history in v1 unless explicitly requested

## Non-Goals For This Architecture Step

- No real AI API calls.
- No Supabase SDK or sync behavior.
- No networking.
- No HealthKit.
- No notifications.
- No Google Calendar.
- No broad UI redesign.
- No full chat screen by default.

