# Product Spec

## Product Summary

This is a private personal life-organization mobile app for tracking and managing the user's core day-to-day responsibilities in one place.

Version 1 focuses on three areas:

- Gym / Health
- University
- Money

The app should be practical, fast to use, and built for repeated daily check-ins. It is not a social product, content platform, or public-facing service.

## Primary Goal

Help the user answer:

- What do I need to do today?
- What have I already done?
- What needs attention soon?
- How am I progressing over time?

## Target User

The app is built for one private user. Design and engineering decisions should favor personal usefulness over generic multi-user flexibility unless future requirements explicitly ask for it.

## Product Principles

- Keep workflows simple and low-friction.
- Prioritize useful tracking over decorative UI.
- Make daily entry fast.
- Make weekly review clear.
- Avoid adding features that do not directly support Gym / Health, University, or Money in v1.
- Preserve data integrity and avoid destructive behavior.

## V1 Areas

### Gym / Health

Purpose: Track training, health habits, and basic wellness consistency.

Possible v1 capabilities:

- Log workouts.
- Track exercise name, sets, reps, weight, and notes.
- Track body metrics if desired, such as weight.
- Track simple habits such as water, sleep, supplements, stretching, or cardio.
- Review recent workout history.
- See basic progress trends.

Out of scope for v1:

- Advanced nutrition planning.
- Medical recommendations.
- Wearable device integrations.
- Social workout sharing.

### University

Purpose: Organize academic responsibilities and progress.

Possible v1 capabilities:

- Track courses or subjects.
- Track assignments, exams, readings, and deadlines.
- Mark academic tasks as pending, in progress, or done.
- See upcoming deadlines.
- Store notes or links per course/task.

Out of scope for v1:

- Full document editing.
- AI essay generation.
- University portal integrations.
- Collaboration with classmates.

### Money

Purpose: Track personal finances clearly enough to understand spending and obligations.

Possible v1 capabilities:

- Log income and expenses.
- Categorize transactions.
- Track recurring payments.
- Track account balances manually.
- Show monthly totals and simple summaries.
- Flag upcoming payments.

Out of scope for v1:

- Bank integrations.
- Investment portfolio management.
- Tax filing.
- Multi-currency automation unless explicitly requested.

## Core Screens To Design Later

No UI should be built yet. Future UI work should likely include:

- Today overview
- Gym / Health dashboard
- University dashboard
- Money dashboard
- Add entry/task/transaction flows
- Review/history views
- Settings or data management

## Data Model Direction

Future implementation should define local data models before building UI. Likely entities:

- Workout
- ExerciseEntry
- HealthMetric
- HabitLog
- Course
- AcademicTask
- Transaction
- MoneyCategory
- RecurringPayment

Exact fields should be decided during implementation planning.

## Privacy And Data

- Treat all data as private personal data.
- Avoid analytics, telemetry, or external services by default.
- Prefer local-first storage for v1 unless explicitly changed.
- Make destructive actions deliberate and reversible where practical.

## Success Criteria For V1

The v1 app is successful when the user can:

- Open the app and understand what needs attention today.
- Log a workout or health habit quickly.
- Track university deadlines and completion status.
- Log income and expenses.
- Review recent activity in each area.
- Trust that existing data is preserved across app sessions.

## Non-Goals

- Public launch readiness.
- Multi-user accounts.
- Social features.
- Complex dashboards before basic tracking works.
- Premature integrations.
- Polished marketing pages.
