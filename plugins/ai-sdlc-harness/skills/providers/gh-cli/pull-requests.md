# GitHub CLI Pull Request Adapter

Provider adapter for GitHub Pull Requests via the `gh` CLI. Used when
`provider-config.md` specifies `Git Provider: gh-cli`.

Use this adapter instead of `providers/github/pull-requests.md` when:
- The GitHub MCP server (`@anthropic/github-mcp`) is not available or not configured.
- The team prefers CLI-based tooling over MCP.

## Prerequisites

```bash
gh --version          # Confirm gh CLI is installed
gh auth status        # Confirm authenticated (runs gh auth login if not)
```

## Tool Reference

All operations use the `Bash` tool to invoke `gh` CLI commands.

### Create a Pull Request

```bash
gh pr create \
  --repo <owner>/<repo> \
  --head <branch> \
  --base <default-branch> \
  --title "<ID-DISPLAY>: <summary>" \
  --body "<PR-body>"
```

**Parameters:**
- `--repo` — `owner/repo` (e.g., `myorg/auth-service`)
- `--head` — Source branch, bare name (e.g., `backend/feature/123-add-notifications`)
- `--base` — Target branch (e.g., `main`, `develop`)
- `--title` — PR title following the project convention
- `--body` — Markdown PR description

**Important:** Bare branch names only — no `refs/heads/` prefix.

**Response:** Prints the PR URL to stdout (e.g., `https://github.com/myorg/auth-service/pull/42`).

### Full Example

```bash
gh pr create \
  --repo myorg/auth-service \
  --head backend/feature/123-add-notifications \
  --base main \
  --title "#123: Add notifications support" \
  --body "Closes #123

## Summary
- Added new configuration endpoint
- Implemented token validation

## Test Plan
- [x] Unit tests pass (92% coverage)
- [x] Integration tests pass"
```

### Draft PR

```bash
gh pr create \
  --repo <owner>/<repo> \
  --head <branch> \
  --base <default-branch> \
  --title "<title>" \
  --body "<body>" \
  --draft
```

### Add PR Comment

```bash
gh pr comment <PR-NUMBER> --repo <owner>/<repo> --body "<Markdown comment>"
```

### View PR Details

```bash
gh pr view <PR-NUMBER> --repo <owner>/<repo> --json number,url,title,state
```

## PR Creation Flow

1. Push the feature branch to remote:
   ```bash
   git -C <repo-path> push -u origin $(git -C <repo-path> rev-parse --abbrev-ref HEAD)
   ```
2. Create the PR with `gh pr create`. Include `Closes #<ISSUE>` in body to
   auto-link and auto-close the GitHub Issue when merged.
3. Capture the PR URL from stdout and record it in the task tracker.
4. For multi-repo stories, use cross-repo references:
   ```
   Closes owner/other-repo#123
   ```

**If work item provider is Jira:** See `skills/providers/shared/pr-conventions.md` — [When Work Item Provider is Jira](../shared/pr-conventions.md#when-work-item-provider-is-jira).

## PR Title Convention

- **Single repo**: `#<ISSUE-NUMBER>: <summary>`
- **Multi-repo**: `#<ISSUE-NUMBER>: <summary> [<RepoName>]`

**If work item provider is Jira:** See `skills/providers/shared/pr-conventions.md` — [When Work Item Provider is Jira](../shared/pr-conventions.md#when-work-item-provider-is-jira).

## Link to Issue (Auto-Close)

GitHub automatically links PRs to issues via keywords in the PR body:

```markdown
Closes #123
```

**Supported keywords**: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`,
`resolve`, `resolves`, `resolved` (case-insensitive).

No separate API call is needed — GitHub handles linking and auto-closing natively.

## Terminology

- **Type**: Pull Request (PR)
- **Source branch flag**: `--head`
- **Target branch flag**: `--base`
- **Branch prefix**: None (bare branch names)

## Provider-Specific Quirks

1. **No branch prefix**: Use bare branch names. Do NOT prepend `refs/heads/`.
2. **Auth required**: `gh auth status` must show an active session before PR creation.
   If not authenticated, prompt the user to run `gh auth login`.
3. **Auto-close via keywords**: `Closes #123` in PR body auto-closes the linked issue
   when the PR is merged.
4. **Shared number space**: PRs and issues share the same number sequence within a repo.
5. **Required reviews**: Branch protection rules on the GitHub repo may require human
   reviews. The workflow's internal reviewer agent doesn't satisfy GitHub's built-in
   review requirement.
6. **Fork-based workflows**: Not typical for internal teams. If used, the `--head` flag
   needs `username:branch-name` format.
