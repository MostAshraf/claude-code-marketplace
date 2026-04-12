# Jira Work Item Adapter

Provider adapter for Jira Issues. Used when `provider-config.md` specifies
`Work Item Provider: jira`.

## MCP Server

- **Package**: Atlassian/Jira MCP server (e.g., `@anthropic/atlassian-mcp` or community equivalent)
- **Configuration**: Requires Jira instance URL, user email, and API token.

## Tool Reference

### Fetch an Issue

```
Tool: mcp__jira__get_issue
Parameters:
  - issueIdOrKey: <string>           # Issue key (e.g., "PROJ-123") or numeric ID
  - expand: "renderedFields"         # Include rendered HTML for rich-text fields
```

**Response mapping:**
- Title → `fields.summary`
- Description → `fields.description` (ADF format — see note below)
- Acceptance Criteria → `fields.customfield_XXXXX` (team-specific custom field — configured in provider-config.md)
- State → `fields.status.name`
- Area/Project → `fields.project.key` + `fields.project.name`
- Iteration/Sprint → `fields.sprint.name` (from Jira Software sprint field)
- Story Points → `fields.story_points` or `fields.customfield_XXXXX`
- Linked Items → `fields.issuelinks[]`
- Subtasks → `fields.subtasks[]`
- Attachments → `fields.attachment[]`

### Fetch Multiple Issues

```
Tool: mcp__jira__search_jql
Parameters:
  - jql: "id in (10001, 10002, 10003)"  # JQL query for batch fetch
  - fields: ["summary", "description", "status", "issuetype"]
  - maxResults: 50
```

### List Comments

```
Tool: mcp__jira__get_issue_comments
Parameters:
  - issueIdOrKey: <string>
```

### List Changelog (Revisions)

```
Tool: mcp__jira__get_issue_changelog
Parameters:
  - issueIdOrKey: <string>
```

**Note:** Jira's changelog is per-field (shows which fields changed), unlike ADO's full
revision snapshots. Useful for tracking status transitions and field edits.

### Get Issue Type Schema

```
Tool: mcp__jira__get_issue_type
Parameters:
  - issueTypeId: <string>
  - projectKey: <string>
```

### Add Comment

```
Tool: mcp__jira__add_comment
Parameters:
  - issueIdOrKey: <string>
  - body: <object>                   # Atlassian Document Format (ADF) or plain text
```

**Note:** Jira comments use ADF (Atlassian Document Format) for rich text. For simplicity,
most MCP servers accept markdown or plain text and convert internally. Check your MCP
server's documentation for the expected format.

### Search Issues (JQL)

```
Tool: mcp__jira__search_jql
Parameters:
  - jql: <string>                    # JQL query (e.g., "project = PROJ AND sprint in openSprints()")
  - fields: [<string>, ...]          # Fields to return
  - maxResults: <integer>
```

**JQL examples for common operations:**
- Sprint stories: `project = PROJ AND sprint in openSprints() AND issuetype = Story`
- By ID: `key = PROJ-123`
- Related to text: `text ~ "user authentication"`
- By epic: `"Epic Link" = PROJ-100`

### Search Code

Jira does not have a code search tool. If code search is needed, use the git provider's
tools or fall back to local `Grep`/`Glob` tools on cloned repos.

## ID Format

- **Type**: String (project key + number)
- **Format**: `PROJ-123`
- **Display format**: `PROJ-123` (no hash prefix — the key is self-describing)
- **In commit messages**: `PROJ-123 #T1: description` (both IDs mandatory)

## Work Item Hierarchy

Typical Jira hierarchy: `Initiative > Epic > Story > Sub-task`

The exact hierarchy depends on the project's issue type scheme. Configure in
`provider-config.md` during init-workspace.

## Provider-Specific Quirks

1. **Acceptance Criteria**: Jira does not have a built-in "Acceptance Criteria" field.
   Teams typically use one of:
   - A custom text field (most common — document the field ID in provider-config.md)
   - The Description field itself (AC mixed into description)
   - Subtasks or checklists (Jira checklist plugins)

   During init-workspace, ask which approach the team uses and record the custom field ID.

2. **ADF (Atlassian Document Format)**: Jira's rich text uses ADF, not HTML or markdown.
   When reading descriptions, use the `renderedFields` expansion to get HTML, then normalize
   to markdown. When posting comments, check if the MCP server accepts markdown directly.

3. **Sprint field**: Not always named `sprint`. It may be a custom field depending on the
   Jira configuration. Record the field name in provider-config.md.

4. **Issue links vs. subtasks**: Jira distinguishes between issue links (related, blocks,
   duplicates) and subtasks (parent-child hierarchy). Both should be extracted when fetching
   an issue.

5. **No code search**: Unlike ADO, Jira has no built-in code search. Use local repo
   search tools instead.

6. **Project key**: Jira organizes issues by project key (e.g., "PROJ"). This replaces
   ADO's project name in most API calls.

## Planner Tool List (for agent frontmatter)

```
mcp__jira__get_issue, mcp__jira__search_jql, mcp__jira__get_issue_comments, mcp__jira__get_issue_changelog, mcp__jira__get_issue_type, mcp__jira__add_comment
```

## Disallowed Tool Pattern (for non-planner agents)

```
mcp__jira__*
```

## Field Mapping Summary

> Concept definitions: `skills/providers/shared/work-item-concepts.md`

| Generic Concept | Jira Field | Notes |
|----------------|------------|-------|
| Title | `fields.summary` | |
| Description | `fields.description` | ADF format; use renderedFields for HTML |
| Acceptance Criteria | `fields.customfield_XXXXX` | Team-specific; configure in provider-config.md |
| State | `fields.status.name` | |
| Area/Project | `fields.project.key` | |
| Sprint | `fields.sprint.name` | May be custom field |
| Story Points | `fields.story_points` | May be custom field |
| Linked Items | `fields.issuelinks[]` | |
| Parent | `fields.parent` | Epic link or parent issue |
| Subtasks | `fields.subtasks[]` | |
