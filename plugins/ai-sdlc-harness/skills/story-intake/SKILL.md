---
name: story-intake
description: >
  Pull and analyse a User Story / Issue from the configured work item provider.
  Use when starting Phase 1 of the development workflow — ingesting requirements,
  parsing acceptance criteria, and surfacing clarifying questions before planning begins.
  Supports ADO, Jira, GitLab, GitHub, Zoho, and local-markdown via provider adapters.
allowed-tools: Bash, Read, Grep, mcp__azure-devops__*, mcp__jira__*, mcp__gitlab__*, mcp__github__*, mcp__zoho__*
argument-hint: "<Work-Item-ID> [project-name]"
---

# Story Intake (Provider-Agnostic)

## Purpose

Pull a User Story / Issue from the configured work item provider, parse its contents
thoroughly, and surface any ambiguities or missing information as clarifying questions
for the human user.

## Arguments

- **First argument** (required): The Work Item / Issue ID
  - ADO: integer (e.g., `123456`)
  - Jira: issue key (e.g., `PROJ-123`)
  - GitLab: issue IID (e.g., `123`)
  - GitHub: issue number (e.g., `123`)
- **Second argument** (optional): Project identifier. Provider-specific default from provider-config.md.

Parse `$ARGUMENTS` to extract these values.

## Provider Resolution

1. **Read `.claude/context/provider-config.md`** to determine the active work item provider.
2. **Read the matching provider adapter** from `skills/providers/<provider>/work-items.md`.
3. Use the adapter's tool reference for all MCP calls in this skill.

If `provider-config.md` does not exist, inform the user:
> "Provider configuration not found. Please run `/init-workspace` first to select your
> work item and git providers."

## Steps

### 1. Fetch the Work Item

Use the **fetch work item** tool from the active provider adapter.

**ADO example:**
```
mcp__azure-devops__wit_get_work_item(id=$ID, project=$PROJECT, expand="relations")
```

**Jira example:**
```
mcp__jira__get_issue(issueIdOrKey=$ID, expand="renderedFields")
```

**GitLab example:**
```
mcp__gitlab__get_issue(projectId=$PROJECT, issueIid=$ID)
```

**GitHub example:**
```
mcp__github__get_issue(owner=$OWNER, repo=$REPO, issueNumber=$ID)
```

### 2. Extract and Display

Using the field mappings from the provider adapter, extract and present:
- Title
- Description (normalize to markdown regardless of source format)
- Acceptance Criteria (extract from dedicated field or parse from description body)
- State / Status
- Area / Project / Labels
- Iteration / Sprint / Milestone
- Linked Items (parent, children, related, epics)
- Attachments (list filenames and types)

**Provider-specific extraction notes:**
- **ADO**: Description and AC are HTML → convert to markdown
- **Jira**: Description is ADF → use renderedFields for HTML → convert to markdown.
  AC may be a custom field — check provider-config.md for the field ID.
- **GitLab / GitHub**: Description is markdown. AC is typically embedded as a task list
  section in the description body — parse the `## Acceptance Criteria` section or
  equivalent pattern documented in provider-config.md.

### 3. Analyse for Gaps

- Are all acceptance criteria testable and unambiguous?
- Are there undefined terms or business concepts that need clarification?
- Are there implicit dependencies on other systems or services?
- Are there missing error/edge case specifications?
- Is the scope clear — what is explicitly OUT of scope?

### 4. Clarify

If ANY gaps found, present numbered clarifying questions to the human user.
- Wait for answers before proceeding.
- Repeat until confident all requirements are clear.

### 5. Output Requirements Summary

```markdown
## Requirements Summary — $ID

**Title**: ...
**Story/Issue ID**: $ID
**Provider**: <ado | jira | gitlab | github>
**Sprint/Milestone**: ...

### Acceptance Criteria (Validated)
1. ...
2. ...

### Clarifications Received
- Q1: ... → A1: ...

### Dependencies
- ...

### Out of Scope
- ...

### Ready for Planning: ✅ YES / ❌ NO (reason)
```

## Rules

- **Never assume.** If something is unclear, ask.
- Do not proceed to planning until the summary shows "Ready for Planning: ✅ YES".
- This skill is read-only with respect to the codebase — it only reads provider data.
- Always read the provider adapter for exact tool names and parameter mappings before
  making any MCP calls.
