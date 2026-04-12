# GitHub Pull Request Adapter

Provider adapter for GitHub Pull Requests. Used when `provider-config.md` specifies
`Git Provider: github`.

## MCP Server

Same as work items: `@anthropic/github-mcp` or `gh` CLI

## Tool Reference

### Create a Pull Request

```
Tool: mcp__github__create_pull_request
Parameters:
  - owner: <string>                  # Repo owner (org or user)
  - repo: <string>                   # Repo name
  - head: <string>                   # Source branch (bare name: "backend/feature/123-add-notifications")
  - base: <string>                   # Target branch (e.g., "main", "develop")
  - title: <string>                  # PR title
  - body: <string>                   # PR description (markdown)
```

**Important:** GitHub uses bare branch names (no `refs/heads/` prefix).

**Response:** Returns the created PR object with `number` and `html_url`.

### Link PR to Issue (Auto-Close)

Like GitLab, GitHub automatically links PRs to issues via keywords in the PR body:

**In PR description** (preferred):
```markdown
Closes #123
```

**Supported keywords**: `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`,
`resolve`, `resolves`, `resolved` (case-insensitive)

**For cross-repo references:**
```markdown
Closes owner/other-repo#123
```

No separate API call needed — GitHub handles linking and auto-closing natively.

### `gh` CLI Alternative

```bash
# Create PR
gh pr create \
  --repo owner/repo \
  --head backend/feature/123-add-notifications \
  --base main \
  --title "#123: Add notifications support" \
  --body "Closes #123

## Summary
- Added new configuration endpoint
- Implemented token validation

## Test Plan
- [ ] Unit tests pass (92% coverage)
- [ ] Integration tests pass"

# The gh CLI returns the PR URL directly
```

The `gh` CLI is often simpler for PR creation and is pre-installed on many dev machines.

### Add PR Comment

```
Tool: mcp__github__create_pull_request_comment
Parameters:
  - owner: <string>
  - repo: <string>
  - pullNumber: <integer>
  - body: <string>                   # Markdown
```

Or via CLI:
```bash
gh pr comment <PR-NUMBER> --repo owner/repo --body "Related PRs: ..."
```

## PR Creation Flow

1. Push the feature branch to remote:
   ```bash
   git -C <repo-path> push -u origin $(git -C <repo-path> rev-parse --abbrev-ref HEAD)
   ```
2. Create the PR via `create_pull_request` (or `gh pr create`) with `Closes #<ISSUE>` in body.
3. GitHub automatically links the PR to the issue and will auto-close when merged.
4. For multi-repo stories, use cross-repo references: `Closes owner/other-repo#123`
5. Return the PR URL for cross-referencing.

**If work item provider is Jira:** See `skills/providers/shared/pr-conventions.md` — [When Work Item Provider is Jira](../shared/pr-conventions.md#when-work-item-provider-is-jira).

## PR Title Convention

- **Single repo**: `#<ISSUE-NUMBER>: <summary>`
- **Multi-repo**: `#<ISSUE-NUMBER>: <summary> [<RepoName>]`

**If work item provider is Jira:** See `skills/providers/shared/pr-conventions.md` — [When Work Item Provider is Jira](../shared/pr-conventions.md#when-work-item-provider-is-jira).

## Terminology

- **Type**: Pull Request (PR)
- **Source branch parameter**: `head`
- **Target branch parameter**: `base`
- **Branch prefix**: None (bare branch names)

## Provider-Specific Quirks

1. **No branch prefix**: Like GitLab, GitHub uses bare branch names. Do NOT prepend
   `refs/heads/`.
2. **Auto-close via keywords**: `Closes #123` in PR body links and auto-closes the issue.
3. **Shared number space**: PRs and issues share the same number sequence within a repo.
   The created PR will get the next available number.
4. **Draft PRs**: Add `--draft` flag to `gh pr create` or set `draft: true` in the API
   call to create a draft PR.
5. **Required reviews**: GitHub repos may have branch protection rules requiring reviews.
   The workflow's internal review process doesn't replace GitHub's built-in review requirement.
6. **`gh` CLI convenience**: For teams that prefer CLI over MCP, the `gh` CLI provides
   equivalent functionality with simpler invocation. Consider using it as the primary
   method if the GitHub MCP server isn't available.
7. **Fork-based workflows**: If the team uses forks, the `head` parameter needs to be
   `username:branch-name`. This is uncommon for internal teams but worth noting.
