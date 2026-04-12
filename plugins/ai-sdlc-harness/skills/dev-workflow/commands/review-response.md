# Phase 7: PR Review Response

**Phase**: 7
**Actor**: Orchestrator, Reviewer (analysis), Planner (task creation), Human gate (GATE #4)

## Prerequisites

- PR(s) created (Phase 6 complete).
- `PR created` timestamp is set in tracker.
- If in direct phase mode, verify:
  ```bash
  ls ai/tasks/*  # tracker must exist
  ls ai/plans/*  # plan must exist
  ```

## Overview

This phase ingests unresolved review comments from open PR(s), challenges each comment
against the approved plan and acceptance criteria, and produces a findings report for the
human. If accepted, the Planner adds new tasks to the existing tracker and the workflow
re-enters the Phase 3 TDD development loop for those tasks only.

## Steps

### Step 1 — Read Configuration and Tracker

```bash
cat .claude/context/repos-paths.md
cat .claude/context/provider-config.md
cat .claude/context/language-config.md
```

Read ALL tracker files in `ai/tasks/` matching the Story ID.

Parse the tracker's **Repo Status** section to build a map of:
`repo-name → { local-path, feature-branch, default-branch }`

Also locate the plan file at `ai/plans/*<STORY-ID>*`.

### Step 2 — Fetch PR Comments (per repo)

For each affected repo, determine the git provider from `provider-config.md` and read the
corresponding git adapter at `skills/providers/<git-provider>/pull-requests.md` to fetch
open review comments.

Use the adapter to:
1. Look up the open PR/MR for the repo's feature branch.
2. Fetch all review threads / comment threads.
3. Filter to **unresolved threads only** — skip automated bot comments, CI check summaries,
   and already-resolved threads.

Collect for each unresolved comment:
- A sequential ID: `[PC-<n>]` (globally numbered across all repos, starting at 1)
- Repo name
- File path and line number (or `"general"` if not inline)
- Comment author and body text
- Thread ID (for replying later, kept in orchestrator state — not shown to human)

**If no unresolved comments are found across all repos:**

```
## Phase 7: PR Review Response

No unresolved review comments found on PR(s) for Story #<STORY-ID>.

Options:
  [1] Re-check — comment threads may have been added recently
  [2] Skip — no action needed
```

Wait for the human's response. If [2], end the phase without updating metrics.

### Step 3 — Reviewer: Challenge Comments Against Plan and AC

For each repo that has unresolved comments, invoke `@reviewer` with
`mode: pr-comment-analysis` and `run_in_background: true`
(name: `reviewer-prcomment-<repo-name>`):

```
@reviewer Analyse PR review comments for Story $ARGUMENTS.

MODE: pr-comment-analysis

[Include LANGUAGE_CTX — reviewer role: include build-cmd, test-cmd; omit format-cmd]
(Templates: ../context/prompt-templates.md)

REVIEW CONTEXT:
- Repo: <repo-name>
- Repo path: <local repo path>
- Feature branch: <team-name>/<type>/<id>-<slug>
- Default branch: <main | master>
- Plan path: <ai/plans/...>
- Story ID: #<STORY-ID>

PR COMMENTS TO ANALYSE:
[PC-<n>] Repo: <repo-name> | File: <file-path>:<line> (or "general") | Author: <author>
         <comment body text>

[PC-<m>] ...

Classify each comment and produce the PR Comment Analysis Report.
See agents/reviewer/index.md for the pr-comment-analysis mode instructions and report format.
```

**Launch all repo reviewers in a single message** (parallel via `run_in_background: true`).
Wait for all to complete.

### Step 4 — Merge Multi-Repo Reports

If multiple repos had comments, collect all PR Comment Analysis Reports. Present them
together, clearly separated by repo, with a merged summary count at the top:

```
Total across all repos — Valid: N | Invalid: N | Partial: N
```

### Step 5 — Present PR Comment Analysis Report to Human (GATE #4)

Display the full merged report.

```
## Phase 7: PR Review Response — Findings

<display report(s)>

The Reviewer has challenged each comment against the approved plan and acceptance criteria.

Options:
  [1] Accept all VALID/PARTIAL findings — create tasks and re-enter the dev loop
  [2] Accept selected findings — specify which [PC-<n>] numbers to address
  [3] Override a classification — specify which [PC-<n>] to reclassify and why
  [4] No action needed — skip

What would you like to do?
```

### Step 6 — Handle Human Response

**Option [1] — Accept all:**
Collect every `[PC-<n>]` classified `VALID` or `PARTIAL`. Proceed to Step 7.

**Option [2] — Accept selected:**
Parse the human's list (e.g., `"PC-1, PC-3"`). Proceed to Step 7 with only those comments.

**Option [3] — Override:**
Capture the human's reclassification reasoning. Re-invoke the relevant Reviewer(s) in
`pr-comment-analysis` mode (foreground, targeted to the specified comments) with the
human's reasoning appended as additional context. Re-present Step 5 with the updated report.

**Option [4] — No action:**
Record `PR review response: skipped` in the Workflow Metrics table. End this phase —
no tasks are created, no commits made.

### Step 7 — Planner: Add New Tasks to Existing Tracker

Collect the accepted `[PC-<n>]` comments along with the Reviewer's proposed task outlines.

Invoke `@planner` (foreground) with the existing tracker and plan:

```
@planner Add new PR-response tasks to the existing tracker for Story $ARGUMENTS.

MODE: pr-response-tasks

CONTEXT:
- Tracker path: <ai/tasks/<existing-tracker-filename>>
- Plan path: <ai/plans/<existing-plan-filename>>
- Story ID: #<STORY-ID>

ACCEPTED PR COMMENTS TO ADDRESS:
[PC-<n>] Repo: <repo-name> | File: <file-path>:<line>
Reviewer classification: VALID | PARTIAL
Reviewer reasoning: <from analysis report>
Proposed task: <one-sentence description from Reviewer>

[PC-<m>] ...

Instructions:
1. Read the existing tracker and plan.
2. Identify the highest existing Task ID (e.g., if last task is T5, next is T6).
3. For EACH accepted PC comment, add ONE new task row to the tracker:
   - Task ID: T<next-n>
   - Repo: <repo-name from the PC comment>
   - Title: <concise title ≤ 60 chars derived from the proposed task>
   - Status: ⏳ Pending
   - Reviewer Verdict: —
   - Commit(s): —
   - Notes: PR-comment: [PC-<n>] | test-required: true
4. Add a Test Outline section for each new task to the PLAN document, following the same
   format and naming convention as the original Test Outline (Subject_Scenario_Outcome).
   Base the test names on the Reviewer's proposed task description.
5. Update the Workflow Metrics table: add `PR review response started | <timestamp>`.
6. Save the updated tracker and plan files. Verify each by reading them back.
```

Parse the Planner's `📋 AGENT STATUS`. If `Outcome: PARTIAL` or `FAILED`, follow the
error handling rules in `orchestrator-rules.md`.

After confirmed `Outcome: SUCCESS`, record `PR review response started` in orchestrator state.

### Step 8 — Re-Enter TDD Development Loop

Read and execute `commands/develop.md`, applying the following scope filter before starting:

> **Only process tasks whose `Notes` column contains `PR-comment:` and `Status: ⏳ Pending`.**

All Phase 3 rules apply unchanged:
- TDD path for `test-required: true` tasks (Tester → Developer → Reviewer)
- Direct path for `test-required: false` tasks (Developer → Reviewer)
- Worktree isolation per task
- Sequential execution within each repo
- Parallel execution across repos (via `run_in_background: true`)
- Squash-merge on Reviewer approval

After all new tasks are ✅ Done across all repos, proceed to Step 9.

### Step 9 — Record Completion and Offer PR Replies

Update the tracker Workflow Metrics: set `PR review response completed` to
`date -u +"%Y-%m-%d %H:%M UTC"`.

Amend the Phase 6 tracker commit (the tracker is already committed after Phase 6):

```bash
git add ai/tasks/
git commit --amend --no-edit
```

Present to the human:

```
## Phase 7: PR Review Response — Complete

All <N> PR-response task(s) have been implemented.

Would you like me to reply to the addressed PR comment threads with commit references?
  [YES] Post replies
  [NO]  Skip
```

**If YES:** For each addressed `[PC-<n>]` comment, use the git provider adapter to post
a reply on the original thread:

```
Addressed in commit <squash-merge-hash>: <one-sentence summary of what was changed>
```

Use the thread IDs captured in Step 2. Route through the provider adapter in
`skills/providers/<git-provider>/pull-requests.md`.

---

## Re-Entry

Phase 7 can be run multiple times for the same PR (e.g., a second round of reviewer
feedback). Each invocation discovers newly unresolved threads, creates a fresh batch of
`PR-comment:` tasks, and runs the dev loop for those tasks only. Prior PR-response tasks
remain Done and are not re-processed.

## Single-Repo Backward Compatibility

If only one repo is affected, this behaves identically — one Reviewer analysis, one human
gate, one Planner invocation, one sequential dev loop.
