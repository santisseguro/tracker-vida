# Roadmap

## Current Phase: Documentation And Foundation

Status: in progress

Goal: Define the app clearly before implementation begins.

Tasks:

- Create product specification.
- Create development roadmap.
- Create Codex working instructions.
- Choose mobile app stack.
- Create initial project scaffold.
- Define v1 data models.

## Phase 1: Project Setup

Goal: Create a minimal mobile app foundation without building feature UI yet.

Tasks:

- Choose framework and tooling.
- Initialize the project.
- Add linting and formatting.
- Add basic test setup.
- Define project folder structure.
- Add environment/config conventions.
- Document how to run the app locally.

Exit criteria:

- Project installs successfully.
- App can run in a simulator or development environment.
- Tests and lint commands exist.
- No product features are implemented yet unless explicitly requested.

## Phase 2: Data Foundation

Goal: Define reliable local data structures for v1.

Tasks:

- Decide local storage approach.
- Define Gym / Health models.
- Define University models.
- Define Money models.
- Add data validation.
- Add seed or fixture data for development if useful.
- Add tests for model behavior.

Exit criteria:

- Core v1 entities are represented in code.
- Data can be created, read, updated, and deleted locally.
- Tests cover important model behavior.

## Phase 3: App Shell

Goal: Add navigation and empty feature areas.

Tasks:

- Create app navigation structure.
- Add top-level areas for Gym / Health, University, and Money.
- Add a Today overview placeholder.
- Add basic empty states.
- Keep UI simple and functional.

Exit criteria:

- User can move between the main app areas.
- No area contains unrelated features.
- Empty states explain only what is needed.

## Phase 4: Gym / Health V1

Goal: Make basic workout and health tracking usable.

Tasks:

- Add workout logging.
- Add exercise entries.
- Add simple habit or health metric logging.
- Add workout history.
- Add basic progress summary.
- Add tests for data and key flows.

Exit criteria:

- User can log and review workouts.
- Existing workout data persists.
- Feature remains scoped to v1 health tracking.

## Phase 5: University V1

Goal: Make academic task tracking usable.

Tasks:

- Add course management.
- Add academic task creation.
- Add due dates and status.
- Add upcoming deadline view.
- Add notes or links where useful.
- Add tests for data and key flows.

Exit criteria:

- User can track courses and academic responsibilities.
- Upcoming deadlines are easy to find.
- Completed tasks remain visible or reviewable.

## Phase 6: Money V1

Goal: Make basic personal finance tracking usable.

Tasks:

- Add transaction logging.
- Add income and expense types.
- Add categories.
- Add recurring payment tracking.
- Add monthly summary.
- Add tests for calculations.

Exit criteria:

- User can log and categorize transactions.
- Monthly totals are accurate.
- Recurring payments can be tracked manually.

## Phase 7: Today Overview And Review

Goal: Bring the three areas together into a daily operating view.

Tasks:

- Show today's health items, university deadlines, and money reminders.
- Add simple weekly review summaries.
- Highlight overdue or upcoming items.
- Keep overview concise and actionable.

Exit criteria:

- User can open the app and know what needs attention.
- Overview links back to the source area for action.

## Phase 8: Polish And Hardening

Goal: Improve reliability and everyday usability.

Tasks:

- Improve loading, error, and empty states.
- Review accessibility basics.
- Add backup/export consideration if needed.
- Improve test coverage around critical flows.
- Fix bugs found during personal use.

Exit criteria:

- App feels dependable for daily use.
- No known data-loss bugs.
- Common workflows are efficient.

## Backlog

Potential future ideas:

- Notifications and reminders.
- Calendar integration.
- Data export.
- Charts and deeper analytics.
- Goal tracking.
- Budget targets.
- Streaks.
- Templates for workouts or recurring academic tasks.

Backlog items should not be implemented until the current phase supports them and the user explicitly asks for them.
