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

   For each fix commit, use the fixup! format so the orchestrator can squash it cleanly:

     fixup! <exact subject of the task commit whose files this fix touches>

   To find the target: run `git -C "<repo-path>" log <default-branch>..<feature-branch> --oneline`
   and identify the task commit that last modified the files your fix touches. Copy its exact
   subject (full first line, verbatim) as the fixup! suffix. If the fix touches files from
   multiple task commits, target the most recently committed one.

   Do NOT use the Co-Authored-By trailer on fixup! commits — they will be squashed away.
   ```

2. After the Developer completes, squash all `fixup!` commits into their target task commits
   non-interactively, per repo:
   ```bash
   GIT_SEQUENCE_EDITOR=true git -C "<repo-path>" rebase -i --autosquash <default-branch>
   ```
   If the rebase exits non-zero, abort and escalate:
   ```bash
   git -C "<repo-path>" rebase --abort
   # Present the conflict output to the human and pause the workflow.
   ```

3. After a successful rebase, re-derive the commit hashes for each task and refresh the
   tracker's **Commit(s)** column before it is committed in Step 6:
   ```bash
   git -C "<repo-path>" log <default-branch>..<feature-branch> --oneline
   ```
   Match each line to its task by the Task ID in the commit subject (e.g. `#T2`).
   Update the `Commit(s)` cell for every affected task row in the working-tree tracker.

4. Re-run Step 2 (pre-PR review) for the affected repos.
5. Re-present Step 3 with the updated report.

Repeat until the human approves or explicitly overrides.

### Step 5 — HUMAN GATE #3

Once the human types `APPROVED` (or chooses to proceed despite issues):

### Step 6 — Commit the Task Tracker

**Before creating the PRs**, commit the task tracker for the first (and only) time.

First, determine whether the workspace `ai/tasks/` directory is inside a git repository:

```bash
git -C ai/tasks/ rev-parse --is-inside-work-tree 2>/dev/null
```

**If the workspace IS a git repo** (exits 0 — the normal case):

```bash
git add ai/tasks/
git commit -m "$(cat <<'EOF'
#<STORY-ID>: add task tracker with final workflow state

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

**If the workspace is NOT a git repo** (exits non-zero — workspace is a plain directory):

For each affected repo, copy the tracker and plan into that repo's `ai/` directories, then commit from the repo:

```bash
# For each affected repo at <REPO_PATH>:
cp ai/tasks/<tracker-file> "<REPO_PATH>/ai/tasks/<tracker-file>"
cp ai/plans/<plan-file>    "<REPO_PATH>/ai/plans/<plan-file>"

git -C "<REPO_PATH>" add ai/tasks/ ai/plans/
git -C "<REPO_PATH>" commit -m "$(cat <<'EOF'
#<STORY-ID>: add task tracker and plan with final workflow state

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

The tracker and plan now travel with the feature branch. All Step 9 amend operations target the same repo commit.

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

After all PRs are created, set `PR created` to `date -u +"%Y-%m-%d %H:%M UTC"` in the tracker file, then amend the tracker commit with the final timestamp.

**If the workspace is a git repo:**

```bash
git add ai/tasks/
git commit --amend --no-edit
```

**If the workspace is NOT a git repo** (tracker was copied into the repo in Step 6):

```bash
# Sync the updated tracker back into the repo, then amend:
cp ai/tasks/<tracker-file> "<REPO_PATH>/ai/tasks/<tracker-file>"
git -C "<REPO_PATH>" add ai/tasks/
git -C "<REPO_PATH>" commit --amend --no-edit
git -C "<REPO_PATH>" push --force-with-lease origin <feature-branch>
```

---

## Single-Repo Backward Compatibility

If only one repo is affected, this behaves identically — one pre-PR review,
one human gate, one PR created, no cross-referencing needed.
