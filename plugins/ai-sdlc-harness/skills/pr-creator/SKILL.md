---
name: pr-creator
description: >
  Create a Pull Request / Merge Request after all tasks and tests are approved.
  Assembles PR summary from the task tracker, validates branch naming, and
  creates the PR/MR via the configured git provider. Links back to the work item
  via the work item provider. Supports ADO, GitLab, GitHub, and Jira.
  Used during Phase 6 of the workflow.
allowed-tools: Bash, Read, Grep, Glob, mcp__azure-devops__*, mcp__jira__*, mcp__gitlab__*, mcp__github__*, mcp__zoho__*
argument-hint: "[Work-Item-ID] [team-name] [repo-name]"
---

# PR Creator (Provider-Agnostic)

## Purpose

Create a Pull Request (or Merge Request) after all development tasks and tests have been
approved by the Reviewer Agent. Links the PR/MR back to the work item in the configured
provider.

## Inputs

- `$ARGUMENTS[0]` — Work Item / Issue ID
- `$ARGUMENTS[1]` — Team name (for branch naming)
- `$ARGUMENTS[2]` — (Optional) Repo name. When provided, operates on a specific repo
  from `repos-paths.md`. When omitted, operates on the current working directory (legacy mode).

## Provider Resolution

1. **Read `.claude/context/provider-config.md`** to determine:
   - The **git provider** (ado, gitlab, github) — for PR/MR creation
   - The **work item provider** (ado, jira, gitlab, github) — for linking
2. **Read the git provider adapter** from `skills/providers/<git-provider>/pull-requests.md`
   (or `merge-requests.md` for GitLab).
3. **If work item provider differs from git provider**, also read the work item provider's
   `pull-requests.md` adapter for the linking step (e.g., `providers/jira/pull-requests.md`
   for adding a remote link in Jira after creating a GitLab MR).

## Pre-Flight Checks

1. **Read ALL tracker files** in `ai/tasks/` matching `*$ARGUMENTS[0]*`.
2. **Verify** every task (including T-TEST / T-TEST-\<RepoName\>) has status ✅ Done.
3. If any task is not done, **STOP** and report which tasks remain.
4. **If repo name provided** (`$ARGUMENTS[2]`): read `.claude/context/repos-paths.md`
   to resolve the repo name to a local path. All git commands below use `git -C <repo-path>`.

## Steps

### 1. Validate Branch Name

Verify the branch in the target repo follows the convention:
```
$ARGUMENTS[1]/feature/$ARGUMENTS[0]-<brief-slug>
```

If a repo name is provided, check via `git -C <repo-path> rev-parse --abbrev-ref HEAD`.
If not on the correct branch, report the issue.

### 2. Gather Summary Data

From the task tracker and git log, collect:
- Story / Issue ID and title
- **Repo name** (if multi-repo, include which repo this PR covers)
- List of completed tasks for this repo (filter by Repo column) with commit hashes
- Number of files changed (`git -C <repo-path> diff --stat` against default branch)
- Test coverage percentage (from the latest run of the repo's configured test command, per `language-config.md`)

### 3. Present Summary to Human

Display:
```markdown
## PR Summary — <ID-DISPLAY>: <Title>

### Tasks Completed
| Task | Title | Commits |
|------|-------|---------|
| T1 | ... | `abc123` |
| T2 | ... | `def456` |
| T-TEST | ... | `ghi789` |

### Stats
- Files changed: X
- Test coverage: XX%
- Plan: ai/plans/...

### Proposed PR/MR
- **Title**: <ID-DISPLAY>: <summary>
- **Source**: <team>/feature/<id>-<slug>
- **Target**: <default-branch>
- **Provider**: <git-provider>
```

Where `<ID-DISPLAY>` follows the work item provider's format:
- ADO: `#12345`
- Jira: `PROJ-123`
- GitLab: `#123`
- GitHub: `#123`

### 4. Wait for Human Approval

> **🚦 GATE: Please respond with APPROVED to create this PR/MR, or describe changes.**

### 5. Push Branch to Remote

Push the feature branch to the remote so the PR/MR can reference it:

```bash
git -C <repo-path> push -u origin $(git -C <repo-path> rev-parse --abbrev-ref HEAD)
```

Verify the push succeeded before proceeding. If it fails, report the error and stop.

**Note:** `git push` is not pre-approved — the user will be prompted to confirm.

### 6. Create the PR / MR

Use the **git provider adapter** for the exact tool and parameters.

#### ADO
```
mcp__azure-devops__repo_create_pull_request(
  repositoryId=<repo-name>,
  project=<project>,
  sourceRefName="refs/heads/<branch>",     # ADO requires refs/heads/ prefix
  targetRefName="refs/heads/<default>",
  title="<ID-DISPLAY>: <summary>",
  description=<PR-body>
)
```

#### GitLab
```
mcp__gitlab__create_merge_request(
  projectId=<project-path>,
  sourceBranch="<branch>",                 # No prefix needed
  targetBranch="<default>",
  title="<ID-DISPLAY>: <summary>",
  description=<MR-body>,                   # Include "Closes #IID" if GitLab is also WI provider
  removeSourceBranch=true
)
```

#### GitHub
```
mcp__github__create_pull_request(
  owner=<owner>,
  repo=<repo>,
  head="<branch>",                         # No prefix needed
  base="<default>",
  title="<ID-DISPLAY>: <summary>",
  body=<PR-body>                           # Include "Closes #NUMBER" if GitHub is also WI provider
)
```

#### GitLab CLI (`glab-cli`)
```bash
glab mr create \
  --repo <group>/<project> \
  --source-branch <branch> \
  --target-branch <default> \
  --title "<ID-DISPLAY>: <summary>" \
  --description "<MR-body>" \
  --remove-source-branch
# MR URL is printed to stdout — capture and record it in the tracker
```

No MCP server required. Bare branch names (no `refs/heads/` prefix).
Include `Closes #IID` in `--description` if GitLab Issues is the work item provider.

#### GitHub CLI (`gh-cli`)
```bash
gh pr create \
  --repo <owner>/<repo> \
  --head <branch> \
  --base <default> \
  --title "<ID-DISPLAY>: <summary>" \
  --body "<PR-body>"
# PR URL is printed to stdout — capture and record it in the tracker
```

No MCP server required. Bare branch names (no `refs/heads/` prefix).
Include `Closes #NUMBER` in `--body` if GitHub Issues is the work item provider.

### 7. Link PR/MR to Work Item

The linking mechanism depends on the **combination** of work item provider and git provider:

| Work Item Provider | Git Provider | Linking Method |
|-------------------|-------------|----------------|
| ADO | ADO | `wit_link_work_item_to_pull_request` (native) |
| Jira | GitLab | Add `Jira: PROJ-123` in MR description + `mcp__jira__add_remote_link` |
| Jira | GitHub | Include `PROJ-123` in PR title for smart commits + `mcp__jira__add_remote_link` |
| GitLab | GitLab | `Closes #IID` in MR description (auto-link) |
| GitHub | GitHub | `Closes #NUMBER` in PR body (auto-link) |
| Jira | ADO | `mcp__jira__add_remote_link` with ADO PR URL |
| GitLab | GitHub | `Closes owner/repo#IID` cross-reference |
| GitHub | GitLab | `Closes group/project#NUMBER` cross-reference |

**If work item provider ≠ git provider:**
1. Create the PR/MR via the git provider (Step 6).
2. Use the work item provider's pull-requests adapter to link back.
3. As fallback, add a comment on the work item with the PR/MR URL.

### 8. Update Tracker

Add PR/MR link to the tracker file and mark workflow as complete.

## PR/MR Title Convention

Adapts based on work item provider's ID format:
- **ADO**: `#<STORY-ID>: <summary>` / `#<STORY-ID>: <summary> [<RepoName>]`
- **Jira**: `<ISSUE-KEY>: <summary>` / `<ISSUE-KEY>: <summary> [<RepoName>]`
- **GitLab**: `#<IID>: <summary>` / `#<IID>: <summary> [<RepoName>]`
- **GitHub**: `#<NUMBER>: <summary>` / `#<NUMBER>: <summary> [<RepoName>]`

## Rules

- **Never create a PR/MR without human approval.**
- PR/MR title MUST include the Work Item / Issue ID.
- All commits in the PR must reference the Story/Issue ID and Task ID.
- Verify no merge commits from default branch — rebase if needed.
- Always read the provider adapter for exact tool names and parameters before making MCP calls.
