# /story-groom Command

Technical enrichment pass. Analyzes relevant repos to identify affected components,
migration concerns, testing strategies, and risks. Produces per-repo technical notes.

## Invocation

The user types `/story-groom [work-item-id]`. This command is always human-invoked.

## Prerequisites

- `.claude/context/provider-config.md` must exist (run `/init-workspace` first).
- `.claude/context/repos-metadata.md` must exist.
- `.claude/context/repos-paths.md` must exist (with valid local paths).
- `.claude/context/conventions.md` should exist (for pattern-aware analysis).
- Work item provider MCP tools must be available (as configured in `provider-config.md`).
- Relevant repos must be cloned locally at the paths specified in `repos-paths.md`.

## Behavior

### Step 1 — Read the Story

Read `.claude/context/provider-config.md` to determine the active work item provider.
Read the matching adapter from `skills/providers/<provider>/work-items.md`.

Use the **fetch work item** tool from the provider adapter to fetch the work item by ID. Extract title,
description, acceptance criteria, and any existing technical notes from comments.

If the story hasn't been refined yet (no clear ACs, missing context), suggest running
`/story-refine` first:

> "This story doesn't have well-defined acceptance criteria yet. Technical grooming is
> more effective on refined stories. Would you like to run `/story-refine` first?"

Proceed if the user wants to continue anyway.

### Step 2 — Identify Relevant Repos

Read `.claude/context/repos-metadata.md` to understand the full repo landscape. Based on the
story's description, acceptance criteria, and domain context, identify which repos are
likely affected.

Present your assessment to the user for confirmation:

> "Based on the story, I think these repos are relevant:
> - **auth-service** — [reason: e.g., 'handles the authentication flow mentioned in AC #2']
> - **api-gateway** — [reason: e.g., 'needs a new route for the endpoint in AC #1']
>
> Does this look right? Any repos to add or remove?"

Wait for confirmation before proceeding. Do not scan repos the user hasn't approved.

### Step 3 — Fetch, Pull, Then Verify Repo State

**This step is a hard prerequisite for Step 4. Do not begin any codebase scan until Step 3 completes for every confirmed repo.**

For each confirmed repo, use the local path from `.claude/context/repos-paths.md` and run through all sub-steps in order:

1. **Path exists**: Check the directory exists and is a git repo.
2. **Fetch from remote** *(mandatory, no exceptions)*: Run `git -C "<path>" fetch origin`.
   This updates local knowledge of the remote without touching the working tree.
   If the fetch fails (no network, bad remote), report the error and **stop for that repo**:
   > "⚠️ [repo-name] — could not reach remote. Check your network or remote config before grooming."
   Do not proceed to the pull or the scan for a repo whose fetch failed.
3. **On default branch**: Run `git -C "<path>" branch --show-current` and compare with the
   default branch from `repos-metadata.md`. If not on the default branch:
   > "⚠️ [repo-name] is on branch `feature/xyz`, not `main`. The technical analysis should
   > be based on the latest default branch to be accurate.
   >
   > Options:
   > 1. **Switch to `main`** — I'll run `git checkout main` and pull before analysing.
   > 2. **Proceed on current branch** — analyse as-is (**warning: results will reflect the
   >    current branch, not the latest default branch — grooming output may be inaccurate**).
   >
   > Please choose (1 or 2):"

   Wait for an explicit numeric choice. Do not default to either option. If the user
   chooses option 1, run `git -C "<path>" checkout <default-branch>` then continue to the
   Pull sub-step below. If the user chooses option 2, skip the pull and proceed directly to
   Step 4 — but surface the warning in the technical notes output so the reader knows the
   analysis may be stale.
4. **Pull latest** *(skipped only if user explicitly chose option 2 above)*: Run
   `git rev-list HEAD..origin/<default-branch> --count` to check if the local branch is
   behind the (now-fetched) remote. If behind, pull automatically:
   ```bash
   git -C "<path>" pull --ff-only origin <default-branch>
   ```
   Report the result:
   > "✅ [repo-name] pulled to latest — now at [short-hash] ([N] new commits)."

   If the pull fails (e.g. local uncommitted changes, diverged history), do not force it.
   **Stop and report** — do not proceed to the scan:
   > "⚠️ [repo-name] — pull failed: [error]. Please resolve manually, then re-run `/story-groom`."

Complete Step 3 for ALL confirmed repos before starting Step 4. A repo whose fetch or pull failed must not be scanned.

### Step 4 — Analyze Each Repo

For each confirmed repo, perform a targeted analysis based on the story's requirements.
This is where Claude Code's native codebase awareness is the primary tool.

**What to look for:**

- **Affected files and classes**: Search for code related to the domain concepts in the story.
  Use the `Grep` tool for content search, `Glob` tool for file pattern matching, and `Read`
  tool for file inspection to identify specific files, classes, and methods that would need
  changes. Do NOT use Bash for searches — always use the dedicated tools.
- **Database impact**: Check for DbContext classes, entity configurations, migrations folder.
  Determine if schema changes are needed based on the story's requirements.
- **API surface**: Look at controllers, route definitions, request/response DTOs. Identify
  if new endpoints are needed or existing ones change.
- **Configuration**: Check `appsettings.json`, startup configuration, DI registrations for
  areas that might need changes.
- **Test coverage**: Look at existing test projects and tests related to the affected areas.
  Note what test types exist and what would need to be added.
- **Dependencies**: Check if the affected code depends on other services, external APIs,
  or shared libraries.

**Use conventions.md** to align your analysis with the team's actual patterns. If conventions
say the team uses the repository pattern, look for repository classes. If they use MediatR,
look for command/query handlers.

**Be concrete.** Don't say "the auth module might be affected." Say "AuthenticationService.cs
(line ~45, the ValidateToken method) handles the token validation that this story modifies.
The related unit tests are in AuthenticationServiceTests.cs."

### Step 5 — Produce Technical Notes

Generate technical notes following the format in `templates/technical-notes.md`. Include
a section for each analyzed repo, plus a Cross-Repo Considerations section if multiple
repos are involved.

### Step 6 — Present and Confirm

Show the full technical notes to the user. Then ask:

> "Would you like me to post these technical notes as a comment on work item #[ID]?"

If the user wants changes, iterate. Technical analysis benefits from developer input —
the user may know about planned refactors, tech debt, or constraints that aren't visible
in the code.

If confirmed, use the **add comment** tool from the provider adapter to add the technical
notes as a comment on the work item.

## Important

- Never modify the work item's Description or Acceptance Criteria fields directly.
  Only add comments.
- Never switch git branches without explicit user approval. Always present a numbered
  choice and wait for a response before running any `git checkout`. Never default or
  assume — if the user's reply is ambiguous, re-prompt.
- **Fetch → Pull → Scan is the non-negotiable order.** `git fetch origin` runs first (mandatory, no exceptions). `git pull --ff-only` follows for repos on the default branch (automatic when behind, pull failure stops the scan for that repo — never force it). Only after both succeed does the codebase scan begin. A repo that could not be fetched or pulled must not be scanned.
- If a repo scan reveals something concerning that's unrelated to the story (e.g., a
  potential bug or tech debt), mention it briefly but keep the focus on the story at hand.
  Don't derail the grooming with unrelated findings.
- The goal is to give developers a head start on understanding the technical scope, not
  to prescribe the implementation. Frame findings as "here's what I see in the code"
  not "here's how you should implement it."
- If you cannot determine the technical impact with reasonable confidence, say so explicitly
  rather than guessing. "I couldn't determine how [X] is currently handled — this should
  be discussed during grooming" is a valid and helpful finding.
