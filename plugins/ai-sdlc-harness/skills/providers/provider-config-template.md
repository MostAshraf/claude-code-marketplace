# Provider Configuration Template

This template is used by `/init-workspace` to generate `.claude/context/provider-config.md`.
Replace placeholders with actual values during workspace setup.

---

# Provider Configuration

## Providers

- **Work Item Provider**: `${WORK_ITEM_PROVIDER}`
- **Git Provider**: `${GIT_PROVIDER}`

## Work Item Provider: `${WORK_ITEM_PROVIDER}`

### MCP Server
- **Package**: `${WI_MCP_PACKAGE}`
- **Verified**: ${WI_MCP_VERIFIED} (set to ✅ during init-workspace after confirming tools are available)

### Tool Mapping

| Operation | MCP Tool | Notes |
|-----------|----------|-------|
| Fetch work item | `${WI_FETCH_TOOL}` | ${WI_FETCH_NOTES} |
| Fetch batch | `${WI_FETCH_BATCH_TOOL}` | ${WI_FETCH_BATCH_NOTES} |
| List comments | `${WI_LIST_COMMENTS_TOOL}` | ${WI_LIST_COMMENTS_NOTES} |
| List revisions/changelog | `${WI_LIST_REVISIONS_TOOL}` | ${WI_LIST_REVISIONS_NOTES} |
| Get item type/schema | `${WI_GET_TYPE_TOOL}` | ${WI_GET_TYPE_NOTES} |
| Add comment | `${WI_ADD_COMMENT_TOOL}` | ${WI_ADD_COMMENT_NOTES} |
| Search items | `${WI_SEARCH_TOOL}` | ${WI_SEARCH_NOTES} |
| Search code | `${WI_SEARCH_CODE_TOOL}` | ${WI_SEARCH_CODE_NOTES} |

### ID Format
- **Format**: `${WI_ID_FORMAT}` (e.g., integer for ADO, string like "PROJ-123" for Jira)
- **Display**: `${WI_ID_DISPLAY}` (e.g., "#12345" for ADO, "PROJ-123" for Jira)

### Field Mapping

| Concept | Provider Field | Notes |
|---------|---------------|-------|
| Title | `${WI_FIELD_TITLE}` | |
| Description | `${WI_FIELD_DESCRIPTION}` | Format: ${WI_DESC_FORMAT} |
| Acceptance Criteria | `${WI_FIELD_AC}` | ${WI_AC_NOTES} |
| State/Status | `${WI_FIELD_STATE}` | |
| Area/Project | `${WI_FIELD_AREA}` | |
| Iteration/Sprint | `${WI_FIELD_ITERATION}` | |
| Story Points | `${WI_FIELD_POINTS}` | |
| Linked Items | `${WI_FIELD_LINKS}` | |

## Git Provider: `${GIT_PROVIDER}`

### MCP Server
- **Package**: `${GIT_MCP_PACKAGE}` (set to `gh-cli` if using GitHub CLI instead of MCP)
- **Verified**: ${GIT_MCP_VERIFIED}

### Tool Mapping

| Operation | MCP Tool / Command | Notes |
|-----------|-------------------|-------|
| Create PR/MR | `${GIT_CREATE_PR_TOOL}` | ${GIT_CREATE_PR_NOTES} |
| Link to work item | `${GIT_LINK_WI_TOOL}` | ${GIT_LINK_WI_NOTES} |

### PR/MR Terminology
- **Type name**: `${GIT_PR_TYPE}` (e.g., "Pull Request" for ADO/GitHub/gh-cli, "Merge Request" for GitLab)
- **Source branch param**: `${GIT_SOURCE_BRANCH_PARAM}`
- **Target branch param**: `${GIT_TARGET_BRANCH_PARAM}`

---
<!-- gh-cli example (copy when Git Provider is gh-cli) -->
<!-- ## Git Provider: `gh-cli`
### MCP Server
- **Package**: `gh-cli` (no MCP server — uses gh CLI via Bash)
- **Verified**: ✅ (confirmed via `gh --version` and `gh auth status`)

### Tool Mapping

| Operation | Command | Notes |
|-----------|---------|-------|
| Create PR | `gh pr create` | Bash tool; returns PR URL on stdout |
| Link to work item | `Closes #N` in PR body | Auto-links GitHub Issues; use Jira adapter for Jira |

### PR/MR Terminology
- **Type name**: Pull Request
- **Source branch flag**: `--head`
- **Target branch flag**: `--base`
- **Branch prefix**: None (bare branch names)

### gh CLI Settings
- **gh_repo**: `<owner>/<repo>` (e.g., `myorg/auth-service`)
-->

---
<!-- glab-cli example (copy when Git Provider is glab-cli) -->
<!-- ## Git Provider: `glab-cli`
### MCP Server
- **Package**: `glab-cli` (no MCP server — uses glab CLI via Bash)
- **Verified**: ✅ (confirmed via `glab --version` and `glab auth status`)

### Tool Mapping

| Operation | Command | Notes |
|-----------|---------|-------|
| Create MR | `glab mr create` | Bash tool; returns MR URL on stdout |
| Link to work item | `Closes #N` in MR description | Auto-links GitLab Issues; use Jira adapter for Jira |

### PR/MR Terminology
- **Type name**: Merge Request
- **Source branch flag**: `--source-branch`
- **Target branch flag**: `--target-branch`
- **Branch prefix**: None (bare branch names)

### glab CLI Settings
- **glab_repo**: `<group>/<project>` (e.g., `myorg/auth-service`)
-->

---
<!-- local-markdown example (copy when Work Item Provider is local-markdown) -->
<!-- ## Work Item Provider: `local-markdown`
### MCP Server
- **Package**: none — file system only
- **Verified**: ✅ (no server required; uses Read/Write tools)

### Tool Mapping
| Operation | Tool / Approach | Notes |
|-----------|----------------|-------|
| Fetch work item | Read tool on file path | File path IS the work item ID |
| Add comment / post back | Write tool to overwrite file | Ask user before overwriting |
| All others | N/A | Not applicable for local files |

### ID Format
- **Format**: File path string (absolute or relative)
- **Display**: Filename (e.g., `auth-story.md`)
- **In commit messages**: Use filename without extension (e.g., `auth-story #T1: description`)

### Field Mapping
| Concept | Markdown Element | Notes |
|---------|-----------------|-------|
| Title | H1 heading (`# ...`) | First H1 in file |
| Description | Content before first section heading | Plain prose |
| Acceptance Criteria | `## Acceptance Criteria` section | |
| Out of Scope | `## Out of Scope` section | |
| Open Questions | `## Open Questions` section | |
| Technical Notes | `## Technical Notes` section | |
| State | N/A | Always "open" |

### local-markdown Settings
- **stories_dir**: `<optional default directory>` (e.g., `./stories`) — leave blank if not set
-->

## Planner Allowed Tools

These are the MCP tools the planner agent should have access to (derived from work item provider):

```
${PLANNER_TOOL_LIST}
```

## Disallowed Tool Pattern

Pattern for blocking provider MCP tools on agents that shouldn't use them:

```
${DISALLOWED_TOOL_PATTERN}
```
