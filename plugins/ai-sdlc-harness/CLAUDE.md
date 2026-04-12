# AI-Driven Development Workflow

This project is a Claude Code harness that orchestrates multi-agent development workflows for User Stories / Issues across multiple repos. Supports multiple work item providers (Azure DevOps, Jira, GitLab, GitHub) and git providers (Azure DevOps, GitLab, GitHub) via a provider adapter layer. No application code lives here — only agents, skills, hooks, and context.

## Quick Start

```
/dev-workflow <Work-Item-ID> [project-name] [team-name]
```

Defaults from `provider-config.md`. See the `/dev-workflow` skill for full workflow documentation.

## Workflow Phases

1. **Requirements Ingestion** — Planner pulls story/issue from configured provider, asks clarifying questions
2. **Planning & Approval** — Planner proposes approaches, human selects one, plan + test outline + tracker generated — **GATE #1**
3. **TDD Development Loop** — For each task: Tester writes failing tests → Developer makes them pass → Reviewer reviews combined diff → squash-merge
4. **Human Approval** — Human reviews full implementation — **GATE #2**
5. **Test Hardening** — Tester fills integration/E2E gaps, enforces ≥ 90% coverage, Reviewer reviews
6. **PR Creation** — Reviewer does holistic pre-PR review of entire feature branch (all tasks combined, impl + tests, against plan + conventions) → detailed report shown to human → human approves — **GATE #3**
7. **PR Review Response** *(on-demand, after Phase 6)* — Reviewer challenges each PR comment against plan + acceptance criteria, classifies as VALID/INVALID/PARTIAL → findings report shown to human → human selects which comments to address — **GATE #4** → Planner adds new tasks → re-enters Phase 3 loop for those tasks. Repeatable across multiple review rounds.

## Critical Ownership Rules

- The **Orchestrator** is the sole owner of the task tracker. It updates status after every agent verdict. The tracker stays **uncommitted** until Phase 6.
- The **Tester** (Phase 3) commits failing tests only — commit format `#<STORY-ID> #<TASK-ID> test: <slug>`. Never writes production code.
- The **Developer** commits production code only (no tracker, no test modifications). Self-manages worktrees in the target repo via `git -C <repo-path>`.
- The **Reviewer** is strictly read-only — NEVER writes or edits any file. Returns its report to the orchestrator.

## Phase 3 Execution Order (NON-NEGOTIABLE)

### Within Each Repo (Sequential)

**For tasks marked `test-required: true` (default):**

1. Orchestrator updates tracker: T(n) → In Progress
2. Tester implements failing tests from the approved Test Outline in the worktree, commits `#<STORY> #T<n> test: <slug>`
3. Tester confirms new tests are **red** (fail for the right reason — not compile error)
4. Developer picks up the same worktree, runs tests (sees red), implements until all tests are green, commits `#<STORY> #T<n> impl: <slug>`
5. Orchestrator updates tracker: T(n) → In Review
6. Reviewer reviews the combined two-commit diff (tests + impl), returns verdict
7. Orchestrator handles verdict:
   - Approved → `git merge --squash` (both commits), tracker → Done, clean up worktree
   - Changes Requested → relay `[R<n>]` comments; if comments touch impl only, re-invoke Developer in SAME worktree; if comments touch tests, re-invoke Tester in SAME worktree; repeat from step 5

**For tasks marked `test-required: false`:**

1. Orchestrator updates tracker: T(n) → In Progress
2. Developer implements T(n) in worktree, commits code only
3. Orchestrator updates tracker: T(n) → In Review
4. Reviewer reviews worktree (read-only), returns verdict
5. Orchestrator handles verdict:
   - Approved → `git merge --squash`, tracker → Done, clean up worktree
   - Changes Requested → relay `[R<n>]` comments to Developer, fix in SAME worktree, repeat from step 3

**NEVER start T(n+1) in the same repo before Reviewer approves T(n).**
**NEVER squash-merge a worktree before Reviewer approves it.**
**NEVER have the Reviewer write or edit any file.**
**NEVER start the Developer on T(n) before the Tester commits failing tests for T(n), unless the task is `test-required: false`.**

### Across Repos (Parallel)

Repo lanes run fully in parallel via `run_in_background: true`. Repos never wait on each other. Cross-repo boundaries are resolved via **contracts** defined by the Planner in Phase 2.

## Legal Tracker Status Transitions

```
⏳ Pending       → 🔧 In Progress
🔧 In Progress   → 🔄 In Review
🔄 In Review     → ✅ Done           (reviewer approved)
🔄 In Review     → 🔧 In Progress    (changes requested)
✅ Done           → 🔧 In Progress    (rework)
```

Any other transition is blocked by the `tracker-transition-guard` hook.

## Non-Negotiable Rules

- Show a brief plan before taking action on any task. Wait for approval before executing.
- All commits: `#<STORY-ID> #<TASK-ID>: description` (both IDs mandatory; Task ID from planner e.g. T1, T2). TDD commits use `test:` or `impl:` suffix — `#<STORY> #T<n> test: <slug>` and `#<STORY> #T<n> impl: <slug>`.
- All branches: `<team>/<type>/<id>-<slug>`
- Build must pass the project's strictness policy as recorded in `language-config.md`. The harness warns at init-workspace time if no zero-warning enforcement mechanism is available for the detected language.
- Tests must achieve ≥ 90% line coverage (test command per language-config.md)
- Task tracker must be updated (in working tree) after every status change — committed once in Phase 6, amended in Phase 7
- Reviewer NEVER writes or edits files — orchestrator owns all tracker updates
- No code before plan approval. No PR before human approval.
- All agents must end responses with a `📋 AGENT STATUS` block
- **Sequential within each repo. Fully parallel across repos.** Cross-repo boundaries resolved via contracts.
- **One PR/MR per repo** in multi-repo stories — all linked to the same work item / issue
- **Every behavioral task begins with a failing test.** The Tester writes tests first (from the approved Test Outline); the Developer only makes them green. Tasks exempt from this are explicitly marked `test-required: false` in the plan.
- **Phase 7 is on-demand** — triggered by `/dev-workflow review-response <story-id>` after PR review comments arrive. It does NOT run automatically as part of the full pipeline.

## Provider Support

The workflow supports multiple providers via adapter skills in `skills/providers/`:

| Provider | Work Items | PRs / MRs | Configuration |
|----------|-----------|-----------|---------------|
| ADO | ✅ | ✅ | `provider-config.md` → `providers/ado/` |
| Jira | ✅ | Via git provider | `provider-config.md` → `providers/jira/` |
| GitLab | ✅ | ✅ (Merge Requests) | `provider-config.md` → `providers/gitlab/` |
| GitHub | ✅ | ✅ | `provider-config.md` → `providers/github/` |
| gh-cli | ❌ (git-only) | ✅ (Pull Requests via `gh` CLI) | `provider-config.md` → `providers/gh-cli/` |
| glab-cli | ❌ (git-only) | ✅ (Merge Requests via `glab` CLI) | `provider-config.md` → `providers/glab-cli/` |
| Zoho | ✅ (Mail Group Tasks) | Via git provider | `provider-config.md` → `providers/zoho/` |
| local-markdown | ✅ (local .md files) | Via git provider | `provider-config.md` → `providers/local-markdown/` |

Provider selection happens during `/init-workspace` and is stored in `.claude/context/provider-config.md`.

## Worktree Fallback (Windows)

Git worktree creation may fail with `error: could not lock config file .git/config: File exists`. If this happens, the Developer reports `Worktree: failed` in its status, and the orchestrator re-invokes without worktree isolation.

## Technology Stack

Per-repo language and framework configuration is discovered by `/init-workspace` and stored in `.claude/context/language-config.md`. Any language is supported — frontend and backend. The harness reads all build, test, coverage, and format commands from the generated context files.
