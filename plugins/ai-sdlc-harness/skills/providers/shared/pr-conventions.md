# Shared PR/MR Conventions

Common patterns shared across all PR/MR provider adapters.
Each adapter references this file instead of repeating these sections.

## PR/MR Title Pattern

All providers follow the same title structure. Replace `<ID>` with the work item's display
format (e.g., `#123` for GitHub/GitLab/ADO issues, `PROJ-123` for Jira).

- **Single repo**: `#<ID>: <summary>`
- **Multi-repo**: `#<ID>: <summary> [<RepoName>]`

## When Work Item Provider is Jira

When Jira is the work item provider (not the git provider's own issue tracker), adjust
PR/MR creation as follows.

### Title

- **Single repo**: `PROJ-123: <summary>`
- **Multi-repo**: `PROJ-123: <summary> [<RepoName>]`

### Body / description

Do **not** use `Closes #<number>` — that would reference a native issue number in the git
provider, not Jira. Use `Relates to PROJ-123` in the description instead.

Include `PROJ-123` in both the title and body to trigger Jira smart commit / app linking.

### After PR/MR creation

Use `skills/providers/jira/pull-requests.md` to add a remote link from the Jira issue to
the PR/MR URL.

## Branch Push Before PR/MR Creation

All PR/MR creation flows start with this step — push the feature branch to the remote:

```bash
git -C <repo-path> push -u origin $(git -C <repo-path> rev-parse --abbrev-ref HEAD)
```
