# Phase 2: Planning & Approval

**Phase**: 2
**Actor**: Planner agent, then Human gate

## Prerequisites

- Phase 1 complete — requirements confirmed by the Planner.
- Feature branch exists.
- If in direct phase mode, verify requirements were ingested by checking for Planner output
  or by re-running Phase 1 first.

## Steps

### Step 1: Design Approach Selection

Delegate to **@planner**:

```
@planner Before decomposing User Story $ARGUMENTS into tasks, propose 2-3 architectural
approaches for implementing this story. For each approach, provide:
1. A short name and one-line summary
2. High-level design (which layers, services, and types are involved)
3. Trade-offs (complexity, performance, maintainability, risk)
4. Your recommendation with reasoning

Present the approaches in a structured DESIGN APPROACHES block for the human to choose from.
Do NOT proceed to task decomposition until the human selects an approach.
```

Present the approaches to the human and wait for a selection. The human may pick one,
request a hybrid, or ask for different options.

### Step 2: Task Decomposition

> **Orchestrator rule:** Do NOT include explicit file paths in the prompt to the Planner.
> The plan-generator skill owns the naming convention (date-prefixed). Providing a path
> causes the Planner to use it instead of the skill's convention, losing the date prefix
> and session ID. Let the skill determine the paths.

Once the human selects an approach, continue with **@planner**:

```
@planner The human selected approach: <SELECTED-APPROACH>.
Decompose User Story $ARGUMENTS into an implementation plan using this approach.
Use the plan-generator skill. Save the plan and task tracker files.
Present the complete plan for human approval.
```

### HUMAN GATE #1

The plan **must** be presented to the human user. Proceed **only** on receiving `APPROVED`.
If changes are requested, have the Planner revise and re-present.

### Record Metric: Plan Approved

Update the tracker's **Workflow Metrics** table — set `Plan approved` to the current UTC timestamp:
```bash
date -u +"%Y-%m-%d %H:%M UTC"
```

### Commit the Plan

Once approved, commit **only the plan file** (the tracker stays uncommitted):

```bash
git add ai/plans/
git commit -m "$(cat <<'EOF'
#<STORY-ID>: add approved implementation plan

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

**The task tracker is NOT committed here.** It remains an uncommitted working file that the
orchestrator updates in-place throughout Phases 3-5. It is committed once before PR creation
in Phase 6.

**This step is done by the orchestrator directly (not delegated to an agent).**

## Next Phase

Proceed to **Phase 3: Develop** — read and execute `commands/develop.md`.
