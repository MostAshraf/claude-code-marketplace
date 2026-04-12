# Pre-Flight: Branch Creation

**Phase**: Pre-flight (runs before any workflow phase)
**Actor**: Orchestrator (not delegated to an agent)

## Prerequisites

None — this is the first step.

## Steps

### 1. Read Repo Configuration

Read the repo registry files to resolve repo names to local paths and default branches:

```bash
cat .claude/context/repos-paths.md
cat .claude/context/repos-metadata.md
```

Parse the `repos-paths.md` table to build a map of `repo-name → local-path`.
Parse `repos-metadata.md` to get each repo's `Default Branch`.

### 2. Determine Affected Repos

Check if a tracker already exists for this story (from a prior session or from the planner):

```bash
ls ai/tasks/*$STORY_ID* 2>/dev/null
```

**If a tracker exists with a Repo Status section:** read the repos from that section.

**If no tracker exists yet:** the planner has not run. The preflight creates branches
in ALL known repos as a safe default. The planner will later identify which repos are
actually affected, and unused branches can be cleaned up.

**Alternative (recommended):** If Phase 1 (requirements) has already identified the
affected repos, use that list. The orchestrator should pass the repo list from the
planner's output to preflight.

### 3. Create Feature Branch in Each Repo

For each affected repo, detect the default branch, pull latest, and create the feature branch:

```bash
# For each repo:
REPO_PATH="<local-path-from-repos-paths.md>"
DEFAULT_BRANCH="<from-repos-metadata.md>"

# Detect default branch (fallback if not in metadata)
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(git -C "$REPO_PATH" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [ -z "$DEFAULT_BRANCH" ]; then
    DEFAULT_BRANCH=$(git -C "$REPO_PATH" remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
  fi
  DEFAULT_BRANCH=${DEFAULT_BRANCH:-master}
fi

# Pull latest and create feature branch
git -C "$REPO_PATH" checkout "$DEFAULT_BRANCH" && git -C "$REPO_PATH" pull origin "$DEFAULT_BRANCH"
git -C "$REPO_PATH" checkout -b "<team-name>/feature/<story-id>-<slug>"
```

Use the convention:
```
<team-name>/feature/<story-id>-<slug>
```

- `<team-name>`: from arguments (no default — must be provided or configured in `provider-config.md`)
- `<story-id>`: the work item / issue ID
- `<slug>`: short kebab-case description derived from the story title

The **same branch name** is used across all repos for consistency.

### 4. Confirm

Report per-repo branch status to the human:

```
Branches created:
  AuthService     → backend/feature/12345-add-subscriptions  (from main)
  BillingService  → backend/feature/12345-add-subscriptions  (from main)
  ApiGateway      → backend/feature/12345-add-subscriptions  (from main)
```

If any repo fails (e.g., uncommitted changes, branch already exists), report the error
and ask the human how to proceed.

### Backward Compatibility

If only one repo is involved (single-repo story), this behaves identically to the
previous preflight — one branch is created in one repo.

## Next Phase

Proceed to **Phase 1: Requirements** — read and execute `commands/requirements.md`.
