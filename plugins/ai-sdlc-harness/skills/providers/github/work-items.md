# GitHub Work Item Adapter

Provider adapter for GitHub Issues. Used when `provider-config.md` specifies
`Work Item Provider: github`.

**Note:** GitHub Issues is typically used when GitHub is both the work item tracker AND
git provider. For teams using Jira with GitHub repos, use the Jira work item adapter instead.

## MCP Server

- **Package**: `@anthropic/github-mcp` or use the `gh` CLI as fallback
- **Configuration**: Requires GitHub personal access token or GitHub App credentials.

## Tool Reference

### Fetch an Issue

```
Tool: mcp__github__get_issue
Parameters:
  - owner: <string>                  # Repo owner (org or user)
  - repo: <string>                   # Repo name
  - issueNumber: <integer>           # Issue number
```

**Response mapping:**
- Title → `title`
- Description → `body` (GitHub Flavored Markdown)
- Acceptance Criteria → Embedded in `body` (typically as task list `- [ ]`)
- State → `state` ("open", "closed")
- Labels → `labels[].name`
- Milestone → `milestone.title` (equivalent to sprint)
- Assignees → `assignees[].login`
- Linked PRs → `pull_request` field (if issue was converted) or timeline events

### Search Issues

```
Tool: mcp__github__search_issues
Parameters:
  - query: <string>                  # GitHub search syntax (e.g., "repo:owner/repo is:issue label:story notifications")
```

**Search query examples:**
- By repo: `repo:myorg/myrepo is:issue is:open`
- By label: `repo:myorg/myrepo is:issue label:user-story`
- By milestone: `repo:myorg/myrepo is:issue milestone:"Sprint 42"`
- Text search: `repo:myorg/myrepo is:issue "user authentication"`

### List Comments

```
Tool: mcp__github__list_issue_comments
Parameters:
  - owner: <string>
  - repo: <string>
  - issueNumber: <integer>
```

### Add Comment

```
Tool: mcp__github__create_issue_comment
Parameters:
  - owner: <string>
  - repo: <string>
  - issueNumber: <integer>
  - body: <string>                   # GitHub Flavored Markdown
```

### Search Code

```
Tool: mcp__github__search_code
Parameters:
  - query: <string>                  # e.g., "repo:myorg/myrepo ValidateToken language:csharp"
```

### `gh` CLI Fallback

If the MCP server is unavailable, the `gh` CLI can perform most operations:

```bash
# Fetch issue
gh issue view 123 --repo owner/repo --json title,body,state,labels,milestone

# List comments
gh issue view 123 --repo owner/repo --comments

# Add comment
gh issue comment 123 --repo owner/repo --body "Comment text"

# Search
gh issue list --repo owner/repo --search "notifications" --json number,title,state
```

## ID Format

- **Type**: Integer (repo-scoped)
- **Format**: `#123`
- **Display format**: `#123` or `owner/repo#123` (cross-repo)
- **In commit messages**: `#123 #T1: description` (both IDs mandatory)

**Note:** GitHub issues and PRs share the same number space within a repo. Issue #5 and
PR #5 cannot coexist. This doesn't affect the workflow but is worth noting.

## Work Item Hierarchy

GitHub's native hierarchy is flat — issues don't have a built-in parent/child relationship.
Teams use various approaches:

- **GitHub Projects** (Projects v2) for board/sprint tracking
- **Milestones** for sprint grouping
- **Labels** for categorization (epic, story, task, bug)
- **Task lists** in issue bodies for sub-items:
  ```markdown
  - [ ] Sub-task 1 (#124)
  - [ ] Sub-task 2 (#125)
  ```
- **Tracked-by / Tracks** relationships (newer GitHub feature)

Document the team's convention in provider-config.md during init-workspace.

## Provider-Specific Quirks

1. **Acceptance Criteria**: GitHub has no dedicated AC field. Like GitLab, teams embed ACs
   in the issue body as markdown task lists. Parse the body to extract AC sections.

2. **Flat hierarchy**: No native epic > story > task hierarchy. Teams simulate it with
   labels, milestones, and task lists. This affects how the planner identifies linked items.

3. **Shared issue/PR number space**: Issues and PRs share sequential numbers within a repo.
   When referencing `#123`, it could be either. Use the issue API specifically.

4. **GitHub Projects**: For sprint/board tracking, GitHub Projects v2 is used instead of
   sprints. The workflow doesn't directly interact with Projects but should be aware of it.

5. **Markdown native**: All text fields use GitHub Flavored Markdown. No conversion needed.

6. **Rate limiting**: GitHub API has rate limits (5000 req/hour for authenticated users).
   The workflow's usage should be well within limits, but worth noting.

7. **`gh` CLI as powerful fallback**: The `gh` CLI is often more convenient than MCP for
   simple operations and is likely already installed on developer machines.

## Planner Tool List (for agent frontmatter)

```
mcp__github__get_issue, mcp__github__search_issues, mcp__github__list_issue_comments, mcp__github__create_issue_comment, mcp__github__search_code
```

## Disallowed Tool Pattern (for non-planner agents)

```
mcp__github__*
```

## Field Mapping Summary

> Concept definitions: `skills/providers/shared/work-item-concepts.md`

| Generic Concept | GitHub Field | Notes |
|----------------|-------------|-------|
| Title | `title` | |
| Description | `body` | GitHub Flavored Markdown |
| Acceptance Criteria | Embedded in `body` | Parse task lists or AC section |
| State | `state` | "open" or "closed" |
| Area/Project | `owner/repo` | |
| Sprint | `milestone.title` | |
| Story Points | None (use labels) | No native field; some teams use labels like "points:3" |
| Linked Items | Task lists / timeline | No native linking; use task lists in body |
| Labels | `labels[].name` | Used for type, priority, etc. |
