# Phase 1: Requirements Ingestion

**Phase**: 1
**Actor**: Planner agent

## Prerequisites

- Feature branch exists and is checked out (run `preflight` first).
- If in direct phase mode, verify the branch exists:
  ```bash
  git branch --show-current  # should match <team>/feature/<story-id>-*
  ```

## Steps

Delegate to the **@planner** agent:

```
@planner Take User Story / Issue $ARGUMENTS. Pull the story from the configured
work item provider (read provider-config.md first), analyse the requirements
thoroughly, and surface any clarifying questions. Do NOT proceed to planning
until all ambiguities are resolved. Use the story-intake skill.
```

**Wait** for the Planner to confirm requirements are fully understood.

If the human provides answers to clarifying questions, pass them to the Planner:

```
@planner The human provided these answers to the clarifying questions:
<answers>

Resolve the ambiguities with this information and confirm the requirements are complete.
```

Repeat until the Planner confirms all requirements are understood — no open ambiguities.

## Next Phase

Proceed to **Phase 2: Plan** — read and execute `commands/plan.md`.
