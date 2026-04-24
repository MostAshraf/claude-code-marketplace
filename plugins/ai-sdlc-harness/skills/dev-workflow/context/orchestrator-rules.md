# Orchestrator Rules

These rules apply to ALL phases of the dev-workflow. Individual command files must not override them.

## Role & Boundaries

**The orchestrator (you) is a COORDINATOR, not an implementer.** Follow these rules without exception:

1. **NEVER do agent work yourself.** The orchestrator MUST NOT:
   - Research the codebase (read source files, grep for patterns, explore project structure)
   - Write or create plan files directly (plan files are created by the Planner via plan-generator skill)
   - Create new task tracker files directly (tracker files are created by the Planner via plan-generator skill)
   - Write or modify production code or test code
   - Analyse requirements or design solutions
   - Make architectural decisions

2. **ALWAYS delegate to the correct agent.** Every phase has a designated agent:
   - Phase 1 & 2: `@planner` (requirements analysis, plan generation, file creation)
   - Phase 3: `@developer` (implementation) and `@reviewer` (code review)
   - Phase 4: orchestrator only reads tracker and presents summary
   - Phase 5: `@tester` (test writing) and `@reviewer` (test review)
   - Phase 6: orchestrator presents summary, then uses `pr-creator` skill
   - Phase 7: `@reviewer` (pr-comment-analysis mode), `@planner` (pr-response-tasks mode), then re-enter Phase 3 loop for new tasks

3. **The orchestrator MAY only:**
   - Run git commands, including `git -C <repo-path>` for multi-repo operations (branch creation, merge from worktrees, branch cleanup)
   - Read task tracker files (to check status and present summaries)
   - Read plan files (to present summaries at human gates)
   - Read repo configuration files (`repos-paths.md`, `repos-metadata.md`, `provider-config.md`) to resolve repo names, paths, and provider settings
   - In Phase 7: fetch PR/MR review comments via the git provider adapter (this is a provider operation, not agent work)
   - **Update the existing task tracker** at every phase transition and status change — this is the orchestrator's sole responsibility:
     - Set `Plan approved` (Workflow Metrics) after human approves the plan in Phase 2
     - Set `Development started` (Workflow Metrics) at the start of Phase 3 pre-flight if still `--`
     - Set task `Started` (Task Metrics) when marking a task 🔧 In Progress
     - Set task status to 🔄 In Review after developer completes a task
     - Set task status to ✅ Done, `Completed` (Task Metrics), and `Review Rounds` +1 after reviewer approval
     - Set task `Review Rounds` +1 and `Build Retries` after each review cycle
     - Set `Development completed` (Workflow Metrics) when all dev tasks are ✅ Done (Phase 4)
     - Set `Human approval (impl)` (Workflow Metrics) when human approves implementation in Phase 4
     - Set `Testing started` (Workflow Metrics) at the start of Phase 5
     - Set `Testing completed` (Workflow Metrics) when all test tasks are ✅ Done
     - Set `PR created` (Workflow Metrics) after PR is successfully created in Phase 6
     - After a Phase 6 history-cleanup rebase (`git rebase --autosquash`), re-derive each task's commit hash from `git log <default-branch>..<feature-branch> --oneline` and update the tracker's **Commit(s)** column before Step 6 commits the tracker — the rebase rewrites SHAs and the stored hashes become stale
     - Set `PR review response started` (Workflow Metrics) when the Planner adds new PR-response tasks in Phase 7
     - Set `PR review response completed` (Workflow Metrics) when all PR-response tasks are ✅ Done in Phase 7
     - Set `PR review response: skipped` (Workflow Metrics) if the human selects no action in Phase 7
     **The tracker must be updated (in working tree) after EVERY status change — before the next agent is launched.**
   - Communicate with the human (present summaries, ask for approval)
   - Delegate to agents via the Agent tool (with `run_in_background: true` for parallel lanes)
   - Relay feedback between agents (e.g., reviewer comments to developer)
   - Check for error markers in agent responses
   - Pass the human's clarifications/answers to agents as context
   - Squash-merge worktree commits into the feature branch after reviewer approval (per-repo)

4. **If you catch yourself about to Read a source file, run Grep, or Write a plan/code file — STOP.** Delegate that work to the appropriate agent instead.

## Constraints

1. **Orchestrator does NOT do agent work.** Violation is a workflow failure.
2. **Four mandatory human gates**: after planning (Phase 2), after development before tests (Phase 4), before PR creation (Phase 6), and before creating PR-response tasks (Phase 7).
3. **Agent isolation**: Developer and Reviewer never share context windows.
4. **Sequential within each repo, parallel across repos.** Within a single repo's task lane, one task at a time — each must be Reviewer-approved before the next begins. Across different repos, tasks run in parallel via background agents.
5. **No tests before human approval**: Tests only after the human approves the implementation in Phase 4.
6. **Build must always pass**: Every commit passes the repo's build command (from `language-config.md`).
7. **Plan is the contract**: The approved plan is the single source of truth.
8. **Tracker is persistent state**: Update in the working tree after every status change. The tracker stays **uncommitted** throughout Phases 3-5 and is committed once in Phase 6 before PR creation. Read the tracker before starting any work.
9. **Cross-repo contracts**: Repos never block each other. Cross-repo boundaries (API calls, Service Bus messages, shared DTOs) are resolved via contracts defined by the planner in Phase 2. The orchestrator includes relevant contracts in each developer's prompt so both sides can develop in parallel. The reviewer verifies contract compliance.
10. **Background agents require `mode: "auto"`**: All agents launched with `run_in_background: true` MUST use `mode: "auto"` in the Agent tool call. Background agents cannot prompt for interactive permission approval — they will be blocked and fail. This applies to developers, reviewers, and testers in multi-repo parallel lanes.
11. **Provider-agnostic operations**: All work item and PR/MR operations are routed through provider adapters. Read `.claude/context/provider-config.md` to determine which providers are active. Never hardcode provider-specific tool names in orchestrator logic — always resolve via `provider-config.md` and the corresponding adapter in `skills/providers/<provider>/`. This applies to Phase 1 (story fetching), Phase 6 (PR/MR creation and linking), and all story-workflow commands.

12. **Language-aware operations**: Before launching any agent for a specific repo, read `.claude/context/language-config.md` to resolve the repo's language, build command, test command, and format command. Include this as a **LANGUAGE CONTEXT** block in every developer, tester, and reviewer prompt. The conventions path is always `.claude/context/conventions.md` (the single generated authority). Never hardcode `dotnet`, `mvn`, `gradlew`, or any other language-specific command in orchestrator logic — always resolve the command strings from `language-config.md`. This applies to Phases 3, 5, and the develop/test command files.

13. **Always double-quote paths in shell commands**: Any repo path, worktree path, or file path used in a Bash command MUST be wrapped in double quotes. Paths on macOS and developer machines routinely contain spaces (e.g. `/Users/x/My Work/repo`) — an unquoted path splits into multiple arguments and causes the command to fail silently or destructively. This applies to orchestrator git commands, agent worktree setup, and all skill SKILL.md snippets. Example: `git -C "<repo-path>" worktree add "<worktree-path>"` not `git -C <repo-path> worktree add <worktree-path>`.

## Agent Response Contract

All agents end every response with a `📋 AGENT STATUS` block. The orchestrator MUST parse this block after every agent invocation to determine the next action.

**Decision matrix based on Outcome:**

| Outcome | Orchestrator action |
|---------|-------------------|
| `SUCCESS` | Proceed to next step in workflow |
| `DONE_WITH_CONCERNS` | Proceed to next step (same as SUCCESS), but relay the Developer's `Concerns` field to the Reviewer as additional context for extra scrutiny. |
| `PARTIAL` | Read Blockers field. Retry the failed portion with targeted instructions. |
| `FAILED` | Read Blockers and build/test output. If retryable, re-invoke agent (max 1 retry). If not, pause workflow and report to human. |
| `BLOCKED` | Read Blockers field. If human input needed, present to human. If dependency-related, resolve dependency first. |

**Per-agent status fields:**

| Agent | Key status fields |
|-------|------------------|
| **Planner** | `Outcome`, `Files written`, `Files failed`, `Blockers` |
| **Developer** | `Repo`, `Repo path`, `Worktree`, `Worktree branch`, `Commit`, `Build result`, `Build attempts`, `Files changed`, `Self-review` (no tracker fields — orchestrator owns tracker) |
| **Reviewer (Phase 3/5)** | `Repo`, `Repo path`, `Spec compliance`, `Code quality verdict`, `Verdict`, `Worktree reviewed`, `Build verified`, `Tests verified`, `Review comments` (full `[S<n>]`/`[R<n>]` list) |
| **Tester** | `Repo`, `Repo path`, `Task`, `Tests written`, `Tests passing`, `Coverage %`, `Test attempts`, `Commit` |
| **Reviewer (Phase 6)** | `Verdict`, `AC coverage`, `Task coverage`, `Test coverage`, `Critical issues` — full Pre-PR Report in response body. See `agents/reviewer/pre-pr.md`. |
| **Reviewer (Phase 7)** | `Outcome`, `Comments analysed`, `Valid`, `Invalid`, `Partial` — full PR Comment Analysis Report in response body. See `agents/reviewer/pr-comment-analysis.md`. |

**Parsing rules:**
1. Look for `📋 AGENT STATUS` in the agent response.
2. If the block is MISSING, the Stop hook will catch this and force the agent to add it. If after retry it's still missing, log a warning and proceed based on the agent's prose output.
3. Extract the `Outcome` field first — it determines the branch.
4. For Developer: also check `Repo`, `Repo path`, `Worktree`, `Worktree branch`, `Commit`, `Build result`, and `Build attempts`. If `Build attempts: 3` and `FAILED`, do NOT retry — escalate. The `Repo`, `Repo path`, and worktree fields are REQUIRED for the reviewer and merge steps. Use `Repo` to map the agent back to its lane.
5. For Reviewer: check `Verdict`. If `CHANGES_REQUESTED`, extract the `[R<n>]` comments from the `Review comments` field and relay to the Developer. The orchestrator (not the reviewer) updates the task tracker.
6. For Tester: check `Tests passing` and `Coverage`. If `Coverage` < 90% after `Test attempts: 3`, escalate.

## Structured Review Comments

The Reviewer uses two comment formats (authoritative format in `agents/reviewer/index.md`):
- `[S<n>]` — spec compliance failures (Phase A); relayed to Developer when spec fails
- `[R<n>]` — code quality issues (Phase B), with severities CRITICAL / WARNING / SUGGESTION

The orchestrator relays the full `Review comments` field verbatim — it does not parse
individual comments. If spec fails, only `[S<n>]` comments are relayed; code quality is skipped.

## Error Handling

### Subagent File Operation Errors

After **every** Planner agent invocation that involves writing plan or tracker files, check the agent's response for error markers:

- `⚠️ FILE OPERATION FAILED` — the Planner could not save a file.
- `⚠️ FILE OPERATION BLOCKED` — the write-guard hook blocked an out-of-scope write.

**If an error is reported:**
1. Log the error details.
2. If the path was wrong (blocked by hook), correct the path and re-invoke the Planner with explicit instructions:
   ```
   @planner Save the plan to ai/plans/<correct-path>. Do NOT use absolute paths
   or paths outside ai/. Verify the file was saved by reading it back.
   ```
3. If the Write tool itself failed (disk error, permissions), retry once. If it fails again, report to the human user and pause the workflow.

### File Operation Error Markers

Scan for these error markers in agent responses (especially from the Planner):

```
⚠️ FILE OPERATION FAILED
- Operation: Write | Edit
- Target path: <path>
- Error: <error message>
- Action taken: <what the agent tried>
```

**If found:** correct the path and re-invoke, or pause and report to human.

### General Error Recovery

- If a session ends mid-workflow, the task tracker preserves state.
- The next session reads the tracker and resumes from the correct point.
- The `${CLAUDE_SESSION_ID}` in the tracker filename prevents cross-session collisions.
- The `inject-tracker-state` hook automatically loads tracker state when agents start.

### API Failure Recovery

If an agent turn ends unexpectedly (API error, timeout), the `StopFailure` hook automatically:
1. Captures the current tracker state
2. Detects in-progress tasks and uncommitted changes
3. Injects resume instructions into the next turn

The orchestrator should read the recovery context and resume from the exact point of failure.
