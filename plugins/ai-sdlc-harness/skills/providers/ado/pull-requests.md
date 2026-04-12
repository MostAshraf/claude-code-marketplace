# ADO Pull Request Adapter

Provider adapter for Azure DevOps Pull Requests. Used when `provider-config.md` specifies
`Git Provider: ado`.

## MCP Server

Same as work items: `@anthropic/azure-devops-mcp`

## Tool Reference

### Create a Pull Request

```
Tool: mcp__azure-devops__repo_create_pull_request
Parameters:
  - repositoryId: <string>           # ADO repo name or ID
  - project: <string>                # ADO project name
  - sourceRefName: <string>          # Source branch (e.g., "refs/heads/backend/feature/12345-add-notifications")
  - targetRefName: <string>          # Target branch (e.g., "refs/heads/develop")
  - title: <string>                  # PR title
  - description: <string>            # PR description (markdown supported)
```

**Important:** ADO requires `refs/heads/` prefix on branch names.

**Response:** Returns the created PR object with `pullRequestId` and `url`.

### Link PR to Work Item

```
Tool: mcp__azure-devops__wit_link_work_item_to_pull_request
Parameters:
  - workItemId: <integer>            # The ADO work item ID
  - pullRequestUrl: <string>         # Full URL of the created PR
  - project: <string>
```

**Note:** This creates a bidirectional link — the work item shows the PR, and the PR shows
the work item in ADO's UI.

## PR Creation Flow

1. Push the feature branch to remote:
   ```bash
   git -C <repo-path> push -u origin $(git -C <repo-path> rev-parse --abbrev-ref HEAD)
   ```
2. Create the PR via `repo_create_pull_request`.
3. Link the PR to the work item via `wit_link_work_item_to_pull_request`.
4. Return the PR URL for cross-referencing.

## PR Title Convention

- **Single repo**: `#<STORY-ID>: <summary>`
- **Multi-repo**: `#<STORY-ID>: <summary> [<RepoName>]`

## Terminology

- **Type**: Pull Request (PR)
- **Source branch parameter**: `sourceRefName`
- **Target branch parameter**: `targetRefName`
- **Branch prefix**: `refs/heads/` (required)

## Provider-Specific Quirks

1. **Branch ref prefix**: ADO requires `refs/heads/` prefix on all branch references
   in API calls. Always prepend this when calling `repo_create_pull_request`.
2. **Native work item linking**: ADO has first-class PR-to-work-item linking via
   `wit_link_work_item_to_pull_request`. This is simpler than other providers where
   linking requires separate API calls or smart commits.
3. **Repository naming**: The `repositoryId` can be the repo name (string) or GUID.
   Use the repo name from `repos-metadata.md` for readability.
4. **Description format**: ADO PR descriptions support markdown.
