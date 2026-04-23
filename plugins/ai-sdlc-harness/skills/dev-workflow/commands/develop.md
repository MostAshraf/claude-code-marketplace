# Phase 3: TDD Development Loop

**Phase**: 3
**Actors**: Tester agent, Developer agent, and Reviewer agent (orchestrator coordinates)

## Prerequisites

- Plan approved and committed (Phase 2 complete).
- Task tracker exists in `ai/tasks/` with pending tasks.
- Feature branches exist in all affected repos (preflight complete).
- If in direct phase mode, verify:
  ```bash
  ls ai/tasks/*  # tracker must exist
  ls ai/plans/*  # plan must exist
  ```

## Pre-Flight

Before starting, read ALL tracker files in `ai/tasks/` matching the Story ID.

**Read repo configuration:**
```bash
cat .claude/context/repos-paths.md
cat .claude/context/language-config.md
```

Parse the tracker's **Repo Status** section to build a map of
`repo-name → { local-path, feature-branch, default-branch }`.
Also build a language map: `repo-name → { language, build-cmd, restore-cmd, format-cmd, build-adapter-path }`.
Conventions are always at `.claude/context/conventions.md` (not per-repo).
If no Repo Status section exists (legacy tracker), treat all tasks as a single lane keyed on the repo from the story metadata.

**Record metric:** If `Development started` is still `—`, set it to the output of `date -u +"%Y-%m-%d %H:%M UTC"`.

## Execution Model

### Prompt Context Templates

Every agent launch includes standard context blocks: **LANGUAGE_CTX**, **REPO_CTX**, **WORKTREE_CTX**, and **CONTRACTS_CTX**. The full schema for each, including which fields to include or omit per agent role, lives in [`../context/prompt-templates.md`](../context/prompt-templates.md). The steps below reference these templates by name — do not retype them inline.

### Detect Mode

Read the tracker's `Repo` column to build the lane map. Every task has a `Repo` value — single-repo stories have one repo for all tasks, multi-repo stories have several. Single-repo stories run with exactly one lane; all the same steps apply, no cross-repo parallelism needed.

---

## Execution Loop

### Initialization

Group all pending tasks by their `Repo` column into **lanes**:

```
lanes = {
  "AuthService":     { pending: [T1, T2], active: null, phase: "idle" },
  "BillingService":  { pending: [T3],     active: null, phase: "idle" },
}
```

Each lane tracks:
- `pending` — ordered list of tasks not yet started (respecting dependencies)
- `active` — the currently running agent (tester, developer, or reviewer), if any
- `phase` — `idle` | `testing` | `developing` | `reviewing`
- `worktree` / `worktree_branch` — shared worktree for the current task (created by tester or developer)
- `test_commit` — commit hash from the Tester AGENT STATUS (failing tests)
- `impl_commit` — commit hash from the Developer AGENT STATUS (passing implementation)

### Main Loop

Repeat until all lanes are complete (no pending, active, or reviewing tasks):

#### Step 1: Launch Tester or Developer for Idle Lanes

For each lane where `phase == "idle"` and `pending` is non-empty:

1. **Check intra-repo dependencies** — pop the next task T from `pending`, but only if ALL
   its dependencies **within the same repo** are ✅ Done. (Cross-repo dependencies do not
   exist — they are resolved via contracts defined in the plan.)

2. **Update tracker**: T → 🔧 In Progress. Set `Started` in Task Metrics to the output of `date -u +"%Y-%m-%d %H:%M UTC"`.

3. **Capture feature branch state** for the repo:
   ```bash
   REPO_PATH="<from Repo Status>"
   FEATURE_BRANCH=$(git -C "$REPO_PATH" rev-parse --abbrev-ref HEAD)
   FEATURE_HEAD=$(git -C "$REPO_PATH" rev-parse HEAD)
   ```

4. **Read the task's `test-required` flag** from the tracker's Notes column.

**If `test-required: true` → Launch @tester (TDD path):**

Launch **@tester** with `run_in_background: true`, `name: "tester-<repo-name>"`, and `mode: "auto-tdd"`:

   ```
   @tester Write failing tests for task T<n> of Story $ARGUMENTS (auto-tdd mode).
   Commit test code only — do NOT commit the task tracker.
   Do NOT write any production code.
   Report your worktree path, branch, and commit hash in your AGENT STATUS.

   [Include LANGUAGE_CTX — omit format-cmd]
   [Include REPO_CTX]

   TEST OUTLINE FOR T<n> (from approved plan):
   <Copy the Test Outline section for this task exactly as written in the plan>

   Instructions:
   1. Create a worktree in this repo. If worktree creation fails, report it in AGENT STATUS.
   2. Implement EXACTLY the tests listed in the Test Outline above — no more, no less.
   3. Run the test command. Confirm each new test FAILS (red). Acceptable failure: assertion
      error or "type/method not found" (expected — impl doesn't exist yet). NOT acceptable:
      compile errors in test code itself (wrong syntax, wrong test framework usage).
   4. Commit with co-author trailer — test code only:
      ```
      #<STORY-ID> #T<n> test: <slug>

      Co-Authored-By: Claude Code <noreply@anthropic.com>
      ```
   5. Report `test_commit` hash and the list of red tests in AGENT STATUS.
   ```

Mark lane as `phase: "testing"`.

**If `test-required: false` → Launch @developer (direct path):**

Launch **@developer** with `run_in_background: true`, `name: "developer-<repo-name>"`, and `mode: "auto"`:

   ```
   @developer Implement task T<n> for Story $ARGUMENTS.
   This task is test-required: false — no pre-written tests exist. Implement production code only.
   Commit production code only — do NOT commit the task tracker.
   Report your worktree path, branch, and commit hash in your AGENT STATUS.

   [Include LANGUAGE_CTX — omit test-cmd]
   [Include REPO_CTX]
   [Include CONTRACTS_CTX if multi-repo]

   Create a worktree in this repo and work inside it. If worktree creation fails,
   report it in your AGENT STATUS and work directly on the feature branch.
   ```

Mark lane as `phase: "developing"`.

**Launch all eligible lanes in a single message** — this enables true parallelism.

#### Step 1b: Handle Tester Completion → Launch Developer

*(Only applies to lanes in `phase: "testing"`.)*

Parse the `📋 AGENT STATUS` block from the tester.

**If `Outcome: SUCCESS`:**

1. Extract `Worktree`, `Worktree branch`, `test_commit`, `Red tests` from Tester AGENT STATUS.
2. Record `Test Written` in Task Metrics: `date -u +"%Y-%m-%d %H:%M UTC"`.
3. Launch **@developer** in the **SAME worktree** with `run_in_background: true`, `name: "developer-<repo-name>"`, and `mode: "auto"`:

   ```
   @developer Implement task T<n> for Story $ARGUMENTS. Failing tests are already in the worktree.
   Your job: make ALL failing tests pass. Do NOT modify the test files — only write production code.
   Commit production code only — do NOT commit the task tracker.
   Report your worktree path, branch, and commit hash in your AGENT STATUS.

   [Include LANGUAGE_CTX — omit test-cmd]
   [Include WORKTREE_CTX, plus these additional fields:]
   - Tester commit: <test_commit from Tester AGENT STATUS>
   - Red tests to turn green: <Red tests list from Tester AGENT STATUS>
   [Include CONTRACTS_CTX if multi-repo]

   Instructions:
   1. Start by running the test command. Confirm the red tests are indeed failing.
      If any are already green, halt and flag — do not continue.
   2. Implement production code until ALL tests pass and build is clean (zero warnings).
   3. Do NOT touch any test file. If you believe a test is wrong, stop and flag to orchestrator.
   4. Commit with co-author trailer — production code only:
      ```
      #<STORY-ID> #T<n> impl: <slug>

      Co-Authored-By: Claude Code <noreply@anthropic.com>
      ```
   ```

4. Mark lane as `phase: "developing"`.

**If `Outcome: FAILED` (tester could not produce a red test from the outline):**

- Report to human: describe which test name(s) could not be made to fail and why.
- Human decides: (a) amend the Test Outline in the plan and re-invoke tester, or (b) mark the task `test-required: false` and proceed directly with the developer.
- Do NOT auto-proceed to the developer.

**If `Outcome: PARTIAL` or compile error in test code:**
- Re-invoke tester with targeted fix instructions in the same worktree.

#### Step 2: Wait for Agent Completion

Wait for the next background agent to complete (notification arrives automatically).
Identify which lane it belongs to from the agent name (`tester-<repo>`, `developer-<repo>`, or `reviewer-<repo>`).

#### Step 3: Handle Developer Completion

Parse the `📋 AGENT STATUS` block from the developer.

**If `Outcome: SUCCESS` or `DONE_WITH_CONCERNS`:**

1. Extract `Worktree`, `Worktree branch`, `Commit`, `Repo`, `Repo path` fields.
   Record `Build attempts` as T(n) `Build Retries` in Task Metrics.
   Record `Green At` in Task Metrics: `date -u +"%Y-%m-%d %H:%M UTC"`.
   Store developer commit hash as `impl_commit` in the lane state.
2. Update tracker: T(n) → 🔄 In Review.
3. Launch **@reviewer** with `run_in_background: true`, `name: "reviewer-<repo-name>"`, and `mode: "auto"`:

   ```
   @reviewer Review task T<n> for Story $ARGUMENTS.

   [Include LANGUAGE_CTX — omit restore-cmd and format-cmd]
   [Include WORKTREE_CTX, plus:]
   - Developer concerns: <from Developer AGENT STATUS Concerns field, or "none">

   <IF test-required: true — include the following TDD context:>
   TDD CONTEXT:
   - Tester commit (failing tests): <test_commit from lane state>
   - Developer commit (implementation): <impl_commit from lane state>
   - Test Outline for T<n>: <copy from plan>
   This worktree contains TWO commits: first the Tester's (red tests), then the Developer's
   (green implementation). Review them together as one logical change.

   Perform your two-phase review:
   1. SPEC COMPLIANCE (Phase A): Read the plan at ai/plans/*$ARGUMENTS*, find task T<n>,
      and verify every requirement is implemented. If the developer flagged concerns, scrutinize
      those areas especially.
      <IF test-required: true — also verify:>
      - The test files were NOT modified by the Developer commit (Tester owns tests).
      - The tests present in the worktree match the approved Test Outline for T<n>.
      - All tests pass (run the test command).
   2. CODE QUALITY (Phase B): Only if spec passes — run the build command at the worktree
      path, evaluate language conventions and PR checklist.

   Produce your structured review verdict. Label comments as:
   - [R<n>] — change required in production code (Developer must fix)
   - [T<n>] — change required in test code (Tester must fix)
   - [S<n>] — suggestion (non-blocking)
   Do NOT update the tracker — the orchestrator handles that.
   Return your full review report.
   ```

4. Mark lane as `phase: "reviewing"`.

**If `Outcome: FAILED` and `Build attempts: 3`:**
- Set T(n) `Build Retries` to 3. Pause lane, report build failure to human.

**If `Outcome: PARTIAL`:**
- Re-invoke developer with targeted fix instructions (same lane, same background pattern).

**If `Outcome: BLOCKED`:**
- Present blocker to human for resolution.

**If `Next action: "worktree failed — retry without isolation"`:**
- Re-invoke developer without worktree instructions. Developer works directly on the
  feature branch in the repo.

#### Step 4: Handle Reviewer Completion

Parse the Reviewer's `📋 AGENT STATUS` block.

**If `Verdict: APPROVED`:**

1. **Squash-merge** all worktree commits (both `test:` and `impl:` for TDD tasks) into the repo's feature branch:
   ```bash
   REPO_PATH="<from lane>"
   git -C "$REPO_PATH" merge --squash <worktree-branch-from-developer-status>
   git -C "$REPO_PATH" commit -m "$(cat <<'EOF'
#<STORY-ID> #T<n>: <task-title-from-plan>

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
   ```
   The squash captures both the Tester's failing-test commit and the Developer's implementation as one merged commit.

2. **Update tracker**: T(n) Status → ✅ Done, Reviewer Verdict → ✅ Approved, Commit(s) → squash-merge hash.
   Set `Completed` in Task Metrics to the output of `date -u +"%Y-%m-%d %H:%M UTC"`, increment `Review Rounds` by 1.

3. **Clean up** worktree:
   ```bash
   git -C "$REPO_PATH" worktree remove <worktree-path> 2>/dev/null
   git -C "$REPO_PATH" branch -D <worktree-branch> 2>/dev/null
   ```

4. Mark lane as `phase: "idle"`. **Loop back to Step 1** — this lane can now pick up
   its next pending task.

**If `Verdict: CHANGES_REQUESTED`:**

1. **Update tracker**: T(n) Reviewer Verdict → 🔄 Changes Requested. Increment `Review Rounds` by 1.
   Append an entry to the `## Review History` section of the tracker:

   ```
   ### T<n> · Round <Review Rounds> · <date -u +"%Y-%m-%d %H:%M UTC">
   **Repo:** <repo-name>
   <paste the full Review comments field from the Reviewer AGENT STATUS verbatim>
   ```

   Do NOT pause the workflow or notify the human — continue immediately to rework.

2. **Classify review comments** by type:
   - `[R<n>]` — production code changes → route to **Developer**
   - `[T<n>]` — test code changes → route to **Tester**
   - `[S<n>]` — suggestions (non-blocking, include for awareness but do not block)

3. **If there are `[T<n>]` comments (test rework needed):**
   Re-invoke **@tester** in the SAME worktree with `run_in_background: true`, `name: "tester-<repo-name>"`, `mode: "auto-tdd"`:

   ```
   @tester Address the following test review comments for task T<n> of Story $ARGUMENTS.
   You are working in the EXISTING worktree at: <worktree-path>
   Do NOT modify production code — only fix the test code.

   [Include LANGUAGE_CTX — omit restore-cmd and format-cmd]
   [Include WORKTREE_CTX]

   Test review comments to address:
   [T1] description...
   [T2] description...

   Fix each test issue, confirm tests are still red (if impl is being reworked) or still pass
   (if only test style/naming is being fixed), commit, and report updated status.
   ```

   After Tester completes, if `[R<n>]` comments also exist, invoke the Developer next.
   Otherwise, proceed directly to re-launch Reviewer.

4. **If there are `[R<n>]` comments (production code changes needed):**
   Re-invoke **@developer** in the SAME worktree with `run_in_background: true`, `name: "developer-<repo-name>"`, `mode: "auto"`:

   ```
   @developer Address the following review comments for task T<n> of Story $ARGUMENTS.
   You are working in the EXISTING worktree at: <worktree-path>
   Do NOT modify the test files — only fix production code.

   [Include LANGUAGE_CTX — omit test-cmd]
   [Include WORKTREE_CTX]

   Review comments to address:
   [R1] description...
   [R2] description...

   Fix each issue, ensure all tests pass and the build is clean, commit, and report updated status.
   ```

5. Mark lane as `phase: "developing"` (or `"testing"` if only `[T<n>]` comments). Loop back to Step 2.

**If `Outcome: FAILED`:**
- Investigate. If recoverable, retry review. If not, escalate to human.

#### Step 5: Repeat

Continue the main loop until ALL lanes have no pending tasks and no active agents.

### Cross-Repo Contracts (No Blocking)

Repo lanes **never wait on each other**. Cross-repo boundaries (API calls, Service Bus
messages, shared DTOs) are resolved via **contracts** defined by the planner in Phase 2.

- The orchestrator reads the plan's Contracts section and includes relevant contracts
  in each developer's prompt (as shown in Step 1 above)
- The developer implements **against** the agreed contract — the other repo's implementation
  does not need to exist yet
- The reviewer verifies contract compliance: producer matches the contract definition,
  consumer codes against the same contract
- Integration tests in Phase 5 validate both sides of each contract

### Concurrency Rules (Non-Negotiable)

- **Within a repo**: strictly sequential. A lane NEVER has more than one agent at a time.
- **Across repos**: fully parallel. Multiple lanes can have active agents simultaneously.
- **NEVER start T(n+1) in a lane before T(n) is approved by the reviewer.**
- **NEVER squash-merge before the reviewer approves.**
- **NEVER launch the Developer on a `test-required: true` task before the Tester commits failing tests.**
- **Squash-merge is synchronous** — the orchestrator does it between reviewer completion
  and the next task launch. It requires git commands in the specific repo directory.
- **ALWAYS use `git merge --squash`** — never `git cherry-pick` or regular `git merge`.
- **Tester and Developer share the same worktree** for each `test-required: true` task — the
  orchestrator passes the worktree path from the Tester's AGENT STATUS to the Developer.

## Next Phase

Once ALL development tasks across ALL repos are ✅ Done, proceed to **Phase 4: Approve
Implementation** — read and execute `commands/approve-impl.md`.
