# Provider Adapters

This directory contains provider-specific adapter skills that translate generic workflow
operations into provider-specific MCP tool calls. The workflow uses two independent providers:

1. **Work Item Provider** — where stories/issues live (ADO, Jira, GitLab Issues, GitHub Issues)
2. **Git Provider** — where code repos and PRs/MRs live (ADO Repos, GitLab, GitHub)

## How It Works

1. During `/init-workspace`, the user selects their work item and git providers.
2. The selection is saved in `.claude/context/provider-config.md`.
3. All workflow skills (story-intake, pr-creator, story-workflow, dev-workflow) read
   `provider-config.md` to determine which adapter to use.
4. Each adapter documents the exact MCP tool names, parameter mappings, and provider quirks.

## Provider Matrix

| Provider | Work Items | PRs / MRs | MCP Server Required |
|----------|-----------|-----------|---------------------|
| ADO | ✅ Work Items (wit_*) | ✅ Pull Requests (repo_*) | `@anthropic/azure-devops-mcp` |
| Jira | ✅ Issues (get_issue, search_jql) | ❌ (uses git provider) | Atlassian/Jira MCP |
| GitLab | ✅ Issues (optional) | ✅ Merge Requests | GitLab MCP |
| GitHub | ✅ Issues (optional) | ✅ Pull Requests | `@anthropic/github-mcp` |
| gh-cli | ❌ (git-only) | ✅ Pull Requests via `gh` CLI | None — requires `gh` CLI |
| glab-cli | ❌ (git-only) | ✅ Merge Requests via `glab` CLI | None — requires `glab` CLI |
| Zoho | ✅ Group Tasks (ZohoMail_*GroupTask) | ❌ (uses git provider) | `zoho` MCP (user-level) |
| local-markdown | ✅ Local .md file (Read tool) | ❌ (uses git provider) | None — file system only |

## Common Combinations

| Team Setup | Work Item Provider | Git Provider |
|-----------|-------------------|--------------|
| Azure DevOps shop | `ado` | `ado` |
| Jira + GitLab | `jira` | `gitlab` |
| Jira + GitHub | `jira` | `github` |
| Jira + GitHub (no MCP) | `jira` | `gh-cli` |
| GitHub-native | `github` | `github` |
| GitHub-native (no MCP) | `github` | `gh-cli` |
| GitLab-native | `gitlab` | `gitlab` |
| Zoho + GitHub | `zoho` | `github` |
| Zoho + GitHub (no MCP) | `zoho` | `gh-cli` |
| Zoho + GitLab | `zoho` | `gitlab` |
| Zoho + GitLab (no MCP) | `zoho` | `glab-cli` |
| Jira + GitLab (no MCP) | `jira` | `glab-cli` |
| GitLab-native (no MCP) | `gitlab` | `glab-cli` |
| Local file (no tracker) | `local-markdown` | `gh-cli` or `github` or any |

## Shared Reference Files

`providers/shared/` contains definitions and conventions that are common across multiple
adapters. Adapters reference these files instead of repeating the content.

| File | Used By |
|------|---------|
| `shared/work-item-concepts.md` | All `work-items.md` adapters — canonical definitions of Title, Description, AC, State, Sprint, etc. |
| `shared/pr-conventions.md` | All PR/MR adapters — common title pattern, Jira co-use note, branch push command |

## Adding a New Provider

1. Create a new directory under `providers/` (e.g., `providers/linear/`).
2. Add `work-items.md` and/or `pull-requests.md` following the structure of existing adapters.
3. Document the MCP server requirement, tool names, and field mappings.
4. Reference `shared/work-item-concepts.md` in the Field Mapping Summary section.
5. Reference `shared/pr-conventions.md` for the Jira co-use note and title pattern.
6. Update `init-workspace` to include the new provider in the selection prompt.
7. Update `provider-config-template.md` with the new provider's tool mapping table.
