# GitLab Work Item Adapter

Provider adapter for GitLab Issues. Used when `provider-config.md` specifies
`Work Item Provider: gitlab`.

**Note:** GitLab Issues is typically used when GitLab is both the work item tracker AND
git provider. For teams using Jira with GitLab repos, use the Jira work item adapter instead.

## MCP Server

- **Package**: GitLab MCP server (e.g., `@anthropic/gitlab-mcp` or community equivalent)
- **Configuration**: Requires GitLab instance URL (self-hosted or gitlab.com) and personal access token.

## Tool Reference

### Fetch an Issue

```
Tool: mcp__gitlab__get_issue
Parameters:
  - projectId: <string>              # GitLab project path (e.g., "mygroup/myproject") or numeric ID
  - issueIid: <integer>              # Issue IID (project-scoped number, NOT global ID)
```

**Response mapping:**
- Title → `title`
- Description → `description` (GitLab Flavored Markdown)
- Acceptance Criteria → Embedded in description (typically as a task list `- [ ]`)
- State → `state` ("opened", "closed")
- Labels → `labels[]` (used for categorization, priority, etc.)
- Milestone → `milestone.title` (equivalent to sprint/iteration)
- Weight → `weight` (equivalent to story points)
- Linked Issues → requires separate API call (see below)
- Assignees → `assignees[]`

### Search Issues

```
Tool: mcp__gitlab__list_issues
Parameters:
  - projectId: <string>
  - search: <string>                 # Text search
  - labels: <string>                 # Comma-separated label filter
  - milestone: <string>              # Milestone name
  - state: "opened"                  # Filter by state
```

### List Comments (Notes)

```
Tool: mcp__gitlab__list_issue_notes
Parameters:
  - projectId: <string>
  - issueIid: <integer>
```

### Add Comment (Note)

```
Tool: mcp__gitlab__create_issue_note
Parameters:
  - projectId: <string>
  - issueIid: <integer>
  - body: <string>                   # Markdown content
```

**Note:** GitLab comments (called "notes") support GitLab Flavored Markdown natively.
No conversion needed — post markdown directly.

### List Linked Issues

```
Tool: mcp__gitlab__list_issue_links
Parameters:
  - projectId: <string>
  - issueIid: <integer>
```

### Search Code

```
Tool: mcp__gitlab__search_code
Parameters:
  - projectId: <string>              # Or groupId for cross-project search
  - search: <string>
```

## ID Format

- **Type**: Integer (project-scoped IID)
- **Format**: `#123` (within project context)
- **Display format**: `#123` or `mygroup/myproject#123` (cross-project)
- **In commit messages**: `#123 #T1: description` (both IDs mandatory)

**Important:** GitLab uses two ID schemes:
- `id` — global unique ID across the entire GitLab instance
- `iid` — project-scoped sequential number (this is what users see and reference)

Always use `iid` for display and references.

## Work Item Hierarchy

GitLab supports:
- **Epics** (group-level) > **Issues** (project-level) > **Tasks** (issue sub-items)
- Issues can be linked to epics via the `epic_id` field
- Sub-items (tasks) are embedded in the issue description as task lists

## Provider-Specific Quirks

1. **Acceptance Criteria**: GitLab has no dedicated AC field. Teams typically embed ACs
   in the issue description as a markdown task list:
   ```markdown
   ## Acceptance Criteria
   - [ ] Given X, When Y, Then Z
   - [ ] Given A, When B, Then C
   ```
   Parse the description to extract AC sections. During init-workspace, ask the team
   about their convention for marking ACs.

2. **Labels as metadata**: GitLab uses labels for many purposes — priority, type, status,
   team, etc. The team's label taxonomy should be documented in provider-config.md.

3. **Milestones as sprints**: GitLab milestones serve the same purpose as sprints/iterations.
   They have start and due dates.

4. **Weight as story points**: The `weight` field is GitLab's equivalent of story points.
   It's a simple integer field on issues.

5. **Markdown native**: All text fields use GitLab Flavored Markdown. No HTML conversion
   needed (unlike ADO).

6. **Project vs. Group**: Issues belong to projects, epics belong to groups. Some search
   operations can be scoped to a group (spanning multiple projects).

## Planner Tool List (for agent frontmatter)

```
mcp__gitlab__get_issue, mcp__gitlab__list_issues, mcp__gitlab__list_issue_notes, mcp__gitlab__list_issue_links, mcp__gitlab__search_code, mcp__gitlab__create_issue_note
```

## Disallowed Tool Pattern (for non-planner agents)

```
mcp__gitlab__*
```

## Field Mapping Summary

> Concept definitions: `skills/providers/shared/work-item-concepts.md`

| Generic Concept | GitLab Field | Notes |
|----------------|-------------|-------|
| Title | `title` | |
| Description | `description` | GitLab Flavored Markdown |
| Acceptance Criteria | Embedded in `description` | Parse task lists or AC section |
| State | `state` | "opened" or "closed" |
| Area/Project | `projectId` | |
| Sprint | `milestone.title` | |
| Story Points | `weight` | Integer |
| Linked Items | Via `list_issue_links` | Separate API call |
| Parent (Epic) | `epic_id` | Group-level epics |
