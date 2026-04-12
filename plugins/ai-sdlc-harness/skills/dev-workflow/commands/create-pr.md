# Phase 6: PR Creation

**Phase**: 6
**Actor**: Orchestrator, then Human gate

## Prerequisites

- Tests approved (Phase 5 complete).
- ALL tasks (dev + test) are ✅ Done in the tracker.
- `Testing completed` timestamp is set.
- If in direct phase mode, verify by reading the tracker.

## Steps

### Step 1 — Read Repo Configuration

```bash
cat .claude/context/repos-paths.md
cat .claude/context/language-config.md
```

Parse the tracker's **Repo Status** section to identify all affected repos and their
feature branches.

### Step 2 — Pre-PR Holistic Review (per repo, parallel)

For each affected repo, invoke `@reviewer` with `mode: pre-pr` and
`run_in_background: true` (name: `reviewer-prepr-<repo-name>`):

```
@reviewer Pre-PR holistic review for Story $ARGUMENTS.

MODE: pre-pr

[Include LANGUAGE_CTX — reviewer role: include build-cmd, test-cmd, coverage-cmd; omit format-cmd]
(Templates: ../context/prompt-templates.md)

REVIEW CONTEXT:
- Repo path: <local repo path>
- Feature branch: <team-name>/<type>/<id>-<slug>
- Default branch: <main | master>
- Plan path: <ai/plans/...>
- Story ID: #<STORY-ID>

Review the entire feature branch against the full plan and conventions.
Produce the Pre-PR Review Report. See agents/reviewer/index.md for the
pre-pr mode instructions and report format.
```

Wait for all reviewer background agents to complete (one per repo).

### Step 3 — Present Pre-PR Review Report(s) to Human

For each repo, display the full Pre-PR Review Report returned by the Reviewer.
For multi-repo stories, present all reports together, clearly separated by repo.

Then present the gate:

**If all repos are `✅ APPROVED` or `⚠️ APPROVED WITH CONCERNS`:**

```
## Pre-PR Review Complete

<display report(s)>

All repos reviewed. Ready to create PR(s).

Type APPROVED to proceed, or describe any changes you want made first.
```

**If any repo has `❌ CHANGES REQUESTED`:**

```
## Pre-PR Review — Issues Found

<display report(s), highlighting critical issues>

Critical issues were found in <repo(s)>. Options:
  [1] Fix before creating PR (recommended) — I'll invoke the Developer
      to address the critical issues, then re-run the pre-PR review.
  [2] Proceed anyway — create the PR with the issues noted above.

What would you like to do?
```

### Step 4 — Handle Fix Loop (if option [1] chosen)

If the human chooses to fix:

1. For each repo with critical issues, invoke `@developer` with the critical issue
   list, working directly on the feature branch (no worktree needed):
   ```
   Fix the following pre-PR review issues on branch <feature-branch> in <repo-path>:
   <critical issues from the report>
   Commit with: #<STORY-ID> #PR-fix: <short description>
   ```
2. After Developer completes, re-run Step 2 (pre-PR review) for the affected repos.
3. Re-present Step 3 with the updated report.

Repeat until the human approves or explicitly overrides.

### Step 5 — HUMAN GATE #3

Once the human types `APPROVED` (or chooses to proceed despite issues):

### Step 6 — Commit the Task Tracker

**Before creating the PRs**, commit the task tracker for the first (and only) time:

```bash
git add ai/tasks/
git commit -m "#<STORY-ID>: add task tracker with final workflow state"
```

### Step 7 — Create PRs (One Per Repo)

For each affected repo, use the **pr-creator** skill:

```
/pr-creator $ARGUMENTS <team-name> <repo-name>
```

The pr-creator will:
1. Push the repo's feature branch to the remote
2. Create the PR/MR via the configured git provider
3. Link the PR/MR to the work item via the configured work item provider

### Step 8 — Cross-Reference PRs (Multi-Repo Only)

After all PRs are created, update each PR description to include links to the
related PRs in other repos:

```
## Related PRs
- AuthService: PR #<id> — <url>
- BillingService: PR #<id> — <url>
```

### Step 9 — Record Final Metric

After all PRs are created, set `PR created` to `date -u +"%Y-%m-%d %H:%M UTC"`.
Amend the tracker commit with the final timestamp:

```bash
git add ai/tasks/
git commit --amend --no-edit
```

---

## Single-Repo Backward Compatibility

If only one repo is affected, this behaves identically — one pre-PR review,
one human gate, one PR created, no cross-referencing needed.
