# GitLab Merge Request Adapter

Provider adapter for GitLab Merge Requests. Used when `provider-config.md` specifies
`Git Provider: gitlab`.

## MCP Server

Same as work items: GitLab MCP server

## Tool Reference

### Create a Merge Request

```
Tool: mcp__gitlab__create_merge_request
Parameters:
  - projectId: <string>              # GitLab project path or numeric ID
  - sourceBranch: <string>           # Source branch name (NO prefix — just "backend/feature/123-add-notifications")
  - targetBranch: <string>           # Target branch name (e.g., "main", "develop")
  - title: <string>                  # MR title
  - description: <string>            # MR description (markdown)
  - removeSourceBranch: true         # Auto-delete source branch after merge (recommended)
```

**Important:** Unlike ADO, GitLab does NOT require `refs/heads/` prefix on branch names.
Use bare branch names.

**Response:** Returns the created MR object with `iid` (project-scoped) and `web_url`.

### Link MR to Issue (Auto-Close)

GitLab automatically links MRs to issues via keywords in the MR description or commit messages.

**In MR description** (preferred):
```markdown
Closes #123
```

**Supported keywords**: `Closes`, `Fixes`, `Resolves` (case-insensitive)

**For cross-project references:**
```markdown
Closes mygroup/myproject#123
```

No separate API call needed — GitLab handles linking and auto-closing natively.

### Add MR Note (Comment)

```
Tool: mcp__gitlab__create_merge_request_note
Parameters:
  - projectId: <string>
  - mergeRequestIid: <integer>
  - body: <string>                   # Markdown content
```

Useful for adding cross-PR references in multi-repo stories.

## MR Creation Flow

1. Push the feature branch to remote:
   ```bash
   git -C <repo-path> push -u origin $(git -C <repo-path> rev-parse --abbrev-ref HEAD)
   ```
2. Create the MR via `create_merge_request` with `Closes #<ISSUE-IID>` in the description.
3. GitLab automatically links the MR to the issue and will auto-close the issue when merged.
4. For multi-repo stories with separate GitLab projects, use cross-project references:
   `Closes group/project#123`
5. Return the MR URL (`web_url`) for cross-referencing.

## MR Title Convention

- **Single repo**: `#<STORY-IID>: <summary>`
- **Multi-repo**: `#<STORY-IID>: <summary> [<RepoName>]`

**If work item provider is Jira:** See `skills/providers/shared/pr-conventions.md` — [When Work Item Provider is Jira](../shared/pr-conventions.md#when-work-item-provider-is-jira).

## Terminology

- **Type**: Merge Request (MR)
- **Source branch parameter**: `sourceBranch`
- **Target branch parameter**: `targetBranch`
- **Branch prefix**: None (bare branch names)

## Provider-Specific Quirks

1. **No branch prefix**: Unlike ADO, GitLab uses bare branch names in API calls.
   Do NOT prepend `refs/heads/`.
2. **Auto-close via keywords**: Including `Closes #123` in the MR description automatically
   links the MR to the issue and closes the issue when the MR is merged. This replaces
   the explicit linking step needed in ADO.
3. **Remove source branch**: Set `removeSourceBranch: true` to auto-clean feature branches.
4. **Draft MRs**: Prefix the title with `Draft:` to create a draft MR. Remove the prefix
   when ready for review.
5. **Cross-project MRs**: Not natively supported — each MR must be within a single project.
   For multi-repo stories, create separate MRs per project and cross-reference them.
6. **Approvals**: GitLab has built-in approval rules. The MR may require approvals before
   merge depending on project settings. This is outside the workflow's control.
