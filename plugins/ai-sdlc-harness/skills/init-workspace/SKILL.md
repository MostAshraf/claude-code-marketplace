---
name: init-workspace
description: >
  One-time workspace setup. Generates local context files (.claude/context/, git-ignored)
  that all workflows depend on — repo metadata, coding conventions, local repo paths,
  language configuration (discovered, not hard-coded), and provider configuration.
  Supports ADO, Jira, GitLab, GitHub, Zoho, and local-markdown as work item providers,
  plus GitHub CLI (gh-cli) and GitLab CLI (glab-cli) as no-MCP git providers. Run once
  before using /dev-workflow or /story-workflow.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[--full | --refresh-conventions | --refresh-permissions | --keep-legacy]"
---

# /init-workspace — Workspace Setup

One-time workspace setup, or new-developer onboarding. Generates the context files that all other workflows depend on.

> **Hard constraint — human-only command.** `/init-workspace` requires interactive human confirmation during language discovery (Phase 3 negotiate). It MUST NEVER be invoked by a background agent. The orchestrator must never delegate this command to a sub-agent lane. If language configuration is missing when a workflow starts, ask the human to run `/init-workspace` directly.

## Usage

```
/init-workspace                         # First-time setup or onboarding
/init-workspace --full                  # Force full regeneration
/init-workspace --refresh-conventions   # Only regenerate conventions.md
/init-workspace --refresh-permissions   # Only re-propose Bash permissions (Step 3c)
/init-workspace --keep-legacy           # In-place schema upgrade without re-running discovery
```

## Output Files

All generated files live at `.claude/context/`:

| File | Description |
|------|-------------|
| `provider-config.md` | Work item and git provider settings, tool mappings, field mappings |
| `repos-metadata.md` | Each repo's purpose, stack, domain, default branch |
| `repos-paths.md` | Maps repo names to local filesystem paths |
| `language-config.md` | Discovered per-repo language, toolchain, commands, regex patterns, permissions |
| `conventions.md` | Team coding patterns, language baselines, repo-specific patterns |

All files are local and git-ignored. Each developer generates their own set by running `/init-workspace`.

Language configuration is **discovered at setup time** (no hard-coded language adapters). `init-workspace` scans each repo, infers toolchain details, negotiates any gaps with the user, then writes the authoritative `language-config.md` and `conventions.md` files. All agents read only these two files at runtime.

## Reference Documents

| Topic | File |
|-------|------|
| Four-phase language discovery pipeline + `language-config.md` schema | [`language-discovery.md`](language-discovery.md) |
| Bash permissions proposal (Step 3c) and preflight semantics | [`permissions.md`](permissions.md) |
| Legacy schema migration + `--keep-legacy` semantics | [`schema-upgrade.md`](schema-upgrade.md) |

## Behavior

### Step 0 — Detect Existing Context

Before doing anything, check which context files already exist in `.claude/context/`:
- `.claude/context/provider-config.md`
- `.claude/context/repos-metadata.md`
- `.claude/context/repos-paths.md`
- `.claude/context/language-config.md`
- `.claude/context/conventions.md`

Also check for the legacy `ado-config.md` — if it exists but `provider-config.md` does not, offer to migrate per [`schema-upgrade.md`](schema-upgrade.md):
> "I found a legacy `ado-config.md` file. I'll migrate its settings to the new `provider-config.md` format which supports multiple providers."

If **all five files** exist, the workspace is already fully initialized. Inform the user:

> "Your workspace is already fully initialized — all context files exist:
> - `provider-config.md`, `repos-metadata.md`, `repos-paths.md`, `language-config.md`, `conventions.md`
>
> Nothing to do. If you want to update files, use:
> - `/init-workspace --refresh-conventions` to regenerate conventions
> - `/init-workspace --refresh-permissions` to re-propose Bash permissions only
> - `/init-workspace --full` to regenerate everything from scratch"

Then **stop**.

If **some files** exist but not all, inform the user which files are missing and proceed to generate only the missing ones. Offer `--full` to regenerate everything instead.

If **no files** exist, proceed with **full setup** from Step 1.

### Step 1 — Provider Selection

Ask the user to select their work item provider and git provider:

> **Work Item Provider** — where your stories/issues live:
> 1. **ADO** (Azure DevOps Work Items)
> 2. **Jira** (Atlassian Jira Issues)
> 3. **GitLab** (GitLab Issues)
> 4. **GitHub** (GitHub Issues)
> 5. **Zoho** (Zoho Mail Group Tasks)
> 6. **local-markdown** (Local `.md` file — no external system required)

> **Git Provider** — where your code repos and PRs/MRs live:
> 1. **ADO** (Azure DevOps Repos)
> 2. **GitLab** (GitLab Repos + Merge Requests — via GitLab MCP)
> 3. **GitLab CLI** (`glab-cli`) (via `glab` CLI, no MCP needed)
> 4. **GitHub** (GitHub Repos + Pull Requests — via `@anthropic/github-mcp`)
> 5. **GitHub CLI** (`gh-cli`) (via `gh` CLI, no MCP needed)

After selection, **verify MCP server / CLI availability** by exercising a lightweight call:

| Provider | Verification |
|----------|--------------|
| ADO | Call any `mcp__azure-devops__*` tool |
| Jira | Call `mcp__jira__get_issue` |
| GitLab | Call `mcp__gitlab__get_issue` |
| GitHub | Call `mcp__github__get_issue` |
| GitHub CLI | Run `gh --version && gh auth status` |
| GitLab CLI | Run `glab --version && glab auth status` |
| Zoho | Call `mcp__zoho__ZohoMail_getMailAccounts` |
| local-markdown | No verification — `Read`/`Write` tools are always available |

If the required MCP server or CLI is not available or not authenticated, warn the user with the appropriate remediation (`gh auth login`, install MCP server, etc.) and proceed only after they confirm.

### Step 2 — Provider Configuration

Based on the selected providers, collect provider-specific settings.

#### ADO (Work Item Provider)
1. **Organization URL**: e.g., `https://dev.azure.com/your-org`
2. **Project name**: e.g., `MyProject`
3. **Area path**: e.g., `MyProject\Engineering\Backend Team`
4. **Iteration path pattern**: e.g., `MyProject\Sprint 42`
5. **Work item types**: Confirm hierarchy (Epic > Feature > User Story > Task, or custom)
6. **Custom fields**: Any team-specific fields

#### Jira (Work Item Provider)
1. **Jira instance URL**: e.g., `https://your-company.atlassian.net`
2. **Project key**: e.g., `PROJ`
3. **Acceptance Criteria field**: Custom field (get field ID), embedded in description, or subtasks
4. **Sprint field** / **Story points field**: Default or custom field name
5. **Issue types**: Confirm hierarchy

#### GitLab (Work Item Provider)
1. **GitLab URL**: `https://gitlab.com` or self-hosted
2. **Group/Project path**: e.g., `myorg/myproject`
3. **AC convention** and **label taxonomy**

#### GitHub (Work Item Provider)
1. **Organization/Owner**, **issue repo(s)**
2. **AC convention** and **label taxonomy**

#### Zoho (Work Item Provider)
1. **Group ID** — integer from the Zoho Mail URL or group settings. Verify by calling `mcp__zoho__ZohoMail_listGroupTask`. Record as `zoho_group_id`.
2. **Categories** — call `mcp__zoho__ZohoMail_getCategoriesInGroupTasks`. Record names and IDs.
3. **AC convention** — confirm ACs are embedded in the task description under `## Acceptance Criteria` (no dedicated field exists in Zoho Group Tasks).
4. **Assignee Zuids** — record team member Zuids; `ZohoMail_getMailAccounts` returns the current user's Zuid.

#### local-markdown (Work Item Provider)
1. **Default stories directory** (optional): stored as `stories_dir` in `provider-config.md`. Story-workflow commands always accept an explicit file path regardless of this setting.
2. No further configuration needed.

#### Git Provider Settings (if different from work item provider)
Collect repository-specific settings (these overlap with Step 3 — combine them): GitLab project paths, GitHub owner/repo names, ADO already collected above.

### Step 3 — Repo Discovery

Ask the user to provide the local filesystem path for each team repo:

> "Please provide the local path for each of your team's repos, one at a time.
> For example: `/home/dev/repos/auth-service`
> Type 'done' when you've listed all repos."

For each path provided:
1. Verify the path exists and is a git repo.
2. Identify the default branch (`main` or `master`).
3. **Ensure the repo is on the default branch and up to date:**
   ```bash
   git -C <path> checkout <default-branch>
   git -C <path> pull
   ```
   If `git pull` fails (no remote, auth issue), warn but continue with the local state. If the checkout fails (uncommitted changes), warn and proceed on the current branch.
4. **Detect the git provider's remote** by parsing `git remote get-url origin`:
   - `dev.azure.com` / `*.visualstudio.com` → ADO
   - `gitlab.com` or configured GitLab host → GitLab
   - `github.com` → GitHub

   Extract the project/repo identifier from the remote URL.
5. Scan the repo for metadata: name, type, stack, domain, key patterns.
6. Present for confirmation and apply corrections.

Write `.claude/context/repos-metadata.md` with the standard format.

**Multi-language monorepos:** If a single git repo contains more than one primary language (e.g. Python backend + TypeScript frontend), ask the user to register it as **two logical repos** in `repos-paths.md`, each with its own `project_root` (e.g. `monorepo-api` → `/path/to/monorepo/api` and `monorepo-web` → `/path/to/monorepo/web`). The language-config schema is one language per logical repo.

### Step 3b — Language Discovery

Run the four-phase language discovery pipeline (Detect → Infer → Negotiate → Write) per repo. The full procedure, marker file lists, inference rules, negotiation prompts, and `language-config.md` schema live in [`language-discovery.md`](language-discovery.md).

If `--keep-legacy` was passed, follow the in-place upgrade flow in [`schema-upgrade.md`](schema-upgrade.md) instead of running Phase 3 negotiation.

### Step 3c — Permissions Proposal

After Phase 3 negotiate completes for **all repos**, propose Bash permissions and structured-edit `settings.json`. Full procedure (collation, presentation, JSON edit, fallback, preflight semantics) in [`permissions.md`](permissions.md).

### Step 4 — Conventions Extraction

Compose `.claude/context/conventions.md` — the single authoritative conventions file that all agents consume at runtime. Assemble it from three layers:

1. **Team Rules (universal)** — Ask the user before writing:

   > "A few team-wide conventions to capture:
   > 1. **Team name** — used as the branch prefix (e.g. `backend`, `platform`, `payments`).
   >    All feature branches will be `<team-name>/feature/<id>-<slug>`.
   > 2. **Coverage threshold** — minimum line coverage required (default: 90%).
   > 3. **PR title format** — any required prefix or format? (e.g. `[STORY-ID] title`, or leave blank for default)"

   Record the answers as concrete values — never leave `<team>` as a placeholder. The team name is **required**; re-prompt if left blank.

2. **Language Baselines** — one section per distinct language detected across the workspace. Naming, project structure, testing patterns. Generated from the Phase 2 inferences and Phase 3 negotiated answers — **not** from any static adapter file.

3. **Repo-Specific Patterns** — per-repo section with the architecture style, detected frameworks, and any review enforcements the user requested in Phase 3 (e.g. "no DB imports in api/").

Write `.claude/context/conventions.md` with the combined result. This is the only conventions file agents read.

> **SOLID / DRY / YAGNI do NOT live in `conventions.md`.** Those universal engineering principles are baked into the Developer and Reviewer agent prompts directly — static, identical across all projects, not discovered per-repo.

#### `conventions.md` schema

```markdown
# Conventions
<!-- generated by /init-workspace; editable after generation -->

## 1. Team Rules (universal)
- team name: <value — required; re-prompt if blank>
- git commit format: #<STORY-ID> #<TASK-ID>: <imperative>
- branch naming: <team-name>/feature/<id>-<slug>   # use the actual team name
- coverage threshold: <value, default 90%>
- PR title: <value or "default">
- <other team-wide rules>

## 2. Language Baselines

### <language-1>
- naming: <file casing, symbol casing>
- project structure: <layout conventions>
- testing: <framework, location, naming>

## 3. Repo-Specific Patterns

### <repo-name>
- architecture: <layered | hexagonal | MVC | feature-folder | modules | custom>
- frameworks: <FastAPI, Spring Boot, Next.js, ...>
- review enforcements: <e.g. "no DB imports in api/">
```

### Step 5 — Local Repo Paths

Generate `.claude/context/repos-paths.md` mapping repo names to local paths. For multi-language monorepos registered as two logical repos, each entry points to its own `project_root`.

### Step 6 — Generate Provider Config

Read the template from `skills/providers/provider-config-template.md` and fill in all values based on the selections from Steps 1–2. Read the relevant provider adapters from `skills/providers/<provider>/` to populate tool mappings.

Write `.claude/context/provider-config.md` with the completed configuration.

### Step 7 — Summary

Present a summary:

> "Workspace initialized! Here's what was generated:
> - `provider-config.md` — Work items: <provider>, Git: <provider>
> - `repos-metadata.md` — [N] repos registered
> - `repos-paths.md` — local paths configured
> - `language-config.md` — [N] repos with discovered toolchains
> - `conventions.md` — team rules + language baselines + repo-specific patterns
>
> **Languages discovered:**
> - AuthService → python 3.12 (FastAPI, layered, zero_warning_support=linter-based)
> - PaymentGateway → go 1.22 (Gin, hexagonal, zero_warning_support=native)
>
> **Permissions updated:** N Bash entries added to `settings.json`. Restart your session if you hit unexpected permission prompts.
>
> **Next steps:**
> - All context files are local and git-ignored — no commit needed.
> - You're ready to use `/dev-workflow` and `/story-workflow`."

## Flags

- `--full` — Force full setup even if context files exist. Will overwrite all context files. Asks for confirmation before proceeding.
- `--refresh-conventions` — Only regenerate `conventions.md` from the current codebase and prior `language-config.md`. Useful after major architectural changes.
- `--refresh-permissions` — Re-run only Step 3c against the existing `language-config.md`. Does not touch discovery. See [`permissions.md`](permissions.md).
- `--keep-legacy` — In-place schema upgrade for an existing legacy-schema `language-config.md`. See [`schema-upgrade.md`](schema-upgrade.md).
