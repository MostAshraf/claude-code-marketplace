# Phase 4: Human Approval of Implementation

**Phase**: 4
**Actor**: Orchestrator, then Human gate

## Prerequisites

- ALL development tasks are ✅ Done in the tracker.
- Phase 3 complete.
- If in direct phase mode, verify by reading the tracker:
  - All T(n) tasks must have status ✅ Done.
  - `Development started` metric must be set.

## Steps

### Record Metric

Set `Development completed` to the output of `date -u +"%Y-%m-%d %H:%M UTC"`.

### Present Summary

Read the task tracker and present a per-repo summary:
- Story ID and title
- **Per-repo breakdown**:
  - Repo name and branch
  - List of completed tasks with commit hashes
  - Number of files changed (`git -C <repo-path> diff --stat <default-branch>...HEAD`)
- Link to the plan document

**Review round callout** — if any task has `Review Rounds > 0` in Task Metrics, append:

```
### Review Rounds
The following tasks required multiple review rounds during Phase 3.
Full reviewer comments are in the ## Review History section of the tracker.

| Task | Rounds |
|------|--------|
| T<n> | <Review Rounds> |
```

If all tasks were approved on the first pass, omit this section entirely.

### HUMAN GATE #2

Present the summary and request `APPROVED` before proceeding to tests.
If changes are requested, loop back to Phase 3 (`commands/develop.md`) to address them.

### Record Approval Metric

On approval, set `Human approval (impl)` to the output of `date -u +"%Y-%m-%d %H:%M UTC"`.

## Next Phase

Proceed to **Phase 5: Test** — read and execute `commands/test.md`.
