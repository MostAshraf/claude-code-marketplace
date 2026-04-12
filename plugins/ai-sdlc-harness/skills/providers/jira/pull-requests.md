# Jira Pull Request Linking Adapter

Jira is a work item provider only — it does not host git repos or PRs. When using Jira
as the work item provider, PRs are created via the **git provider** (GitLab, GitHub, or ADO).

This adapter handles the Jira side of PR linking: adding a remote link from the Jira issue
to the PR/MR URL created by the git provider.

## When to Use

After the git provider creates a PR/MR, call this adapter to link it back to the Jira issue.

## Tool Reference

### Link PR to Issue (Remote Link)

```
Tool: mcp__jira__add_remote_link
Parameters:
  - issueIdOrKey: <string>           # e.g., "PROJ-123"
  - url: <string>                    # The PR/MR URL from the git provider
  - title: <string>                  # e.g., "PR #42: Add subscription support [auth-service]"
  - relationship: "pull request"     # Relationship type
```

**Alternative — Smart Commits:**
If the MCP server doesn't support `add_remote_link`, Jira can auto-link PRs via smart
commit messages. Include the issue key in commit messages:

```
PROJ-123 [#T1]: add notification configuration endpoint
```

Most Jira+Git integrations (Bitbucket, GitHub for Jira, GitLab for Jira) will automatically
link commits containing issue keys to the corresponding Jira issues.

### Add Comment with PR Link

As a fallback or supplement, add a comment to the Jira issue with the PR details:

```
Tool: mcp__jira__add_comment
Parameters:
  - issueIdOrKey: <string>
  - body: "Pull Request created: [PR #42: Add notifications support|<PR-URL>] in <repo-name>"
```

## PR Linking Flow (Jira + Git Provider)

1. Git provider adapter creates the PR/MR and returns the URL.
2. This adapter links the PR to the Jira issue via `add_remote_link`.
3. If `add_remote_link` is unavailable, fall back to adding a comment with the PR link.
4. For multi-repo stories, repeat for each PR — all linking to the same Jira issue.

## Provider-Specific Quirks

1. **No native PR support**: Unlike ADO, Jira has no built-in PR concept. Integration
   relies on remote links, smart commits, or third-party apps (GitHub for Jira, etc.).
2. **Remote link permissions**: The MCP server's API token needs "edit issues" permission
   to add remote links.
3. **Smart commit format**: `PROJ-123 #comment <text>` adds a comment; `PROJ-123 #time 2h`
   logs time. Use only the issue key for basic linking.
