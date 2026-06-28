# Codex Working Instructions

## Project Context

This repository is for a private personal life-organization mobile app.

Version 1 has three product areas:

- Gym / Health
- University
- Money

Do not build unrelated features. Do not expand scope unless the user explicitly asks.

## Working Style

- Work step by step.
- Prefer small, reviewable changes.
- Make the smallest useful change that satisfies the task.
- Preserve existing behavior.
- Do not rewrite or restructure unrelated code.
- Ask for clarification only when required to avoid a risky or incorrect change.
- If a reasonable assumption is safe, state it briefly and continue.
- Explain changed files after each task.

## Scope Control

Before making changes, identify which v1 area the task belongs to:

- Gym / Health
- University
- Money
- Shared foundation
- Documentation

If a requested change does not fit one of these areas, confirm the scope before implementing it.

## Implementation Rules

- Do not implement app code during documentation-only tasks.
- Do not create UI unless the user explicitly asks for UI work.
- Follow existing project patterns once they exist.
- Keep data models and business logic separate from presentation when practical.
- Avoid adding dependencies unless they clearly reduce complexity or match the chosen stack.
- Favor local-first behavior and privacy-preserving defaults.
- Avoid telemetry, analytics, or external services unless explicitly requested.

## Change Safety

- Check existing files before editing.
- Do not overwrite user changes.
- Do not remove behavior unless the task explicitly requires it.
- Keep migrations and data changes careful and reversible where possible.
- Add or update tests when changing behavior.
- Run relevant verification commands when available.

## Communication

After each task, summarize:

- What changed.
- Which files changed.
- How it was verified, or why verification was not run.
- The recommended next step.

Keep explanations practical and concise.

## Development Priorities

Recommended order for future Codex tasks:

1. Confirm the mobile stack.
2. Scaffold the project.
3. Add linting, formatting, and tests.
4. Define local data models.
5. Build app navigation.
6. Implement Gym / Health v1.
7. Implement University v1.
8. Implement Money v1.
9. Build Today overview.
10. Polish and harden.
