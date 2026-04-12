# /story-analyze Command

> **Note:** For most workflows, `/story-improve` is the recommended alternative — it combines
> readiness analysis with refinement in a single adaptive flow. `/story-analyze` remains
> available when you need a standalone readiness report (e.g., to share with the PO before
> a session without refining the story yet).

Pre-refinement readiness check. Evaluates a user story against quality criteria and
produces a readiness report with actionable flags.

## Invocation

The user types `/story-analyze [work-item-id]`. This command is always human-invoked.

## Prerequisites

- `.claude/context/provider-config.md` must exist (run `/init-workspace` first).
- Work item provider MCP tools must be available (as configured in `provider-config.md`).

## Behavior

### Step 1 — Read the Story

Read `.claude/context/provider-config.md` to determine the active work item provider.
Read the matching adapter from `skills/providers/<provider>/work-items.md`.

Use the **fetch work item** tool from the provider adapter to fetch the work item by ID. Extract:
- Title
- Description (HTML or plain text — normalize to markdown)
- Acceptance Criteria field
- State
- Area Path
- Iteration Path
- Any linked work items (parent, children, related)

If the work item is not found or not accessible, inform the user clearly and stop.

### Step 2 — Load Context

Read `.claude/context/repos-metadata.md` to understand the team's domain landscape. This helps
assess whether the story's scope is realistic and well-bounded.

### Step 3 — Evaluate Readiness

Assess the story against each dimension defined in `templates/readiness-report.md`.
For each dimension, assign a flag (🔴 🟡 🟢) and write a specific explanation.

Key evaluation rules:

**Be specific, not generic.** "Acceptance criteria could be improved" is useless.
"AC #2 says 'system handles errors gracefully' — this isn't testable. Suggest replacing
with 'Given an invalid token, When the user attempts login, Then a 401 response is
returned with error code AUTH_INVALID_TOKEN'" is useful.

**Suggest, don't just critique.** Every red or yellow flag must include a concrete
improvement suggestion. Draft replacement text where possible.

**Consider the audience.** The readiness report will be seen by the PO and the full team.
Keep the tone constructive and collaborative.

**Use domain knowledge.** If the story references concepts from `repos-metadata.md`
(e.g., a specific service or domain area), use that knowledge to assess whether the
scope is realistic and the ACs cover the right scenarios.

### Step 4 — Generate the Report

Produce the readiness report following the format in `templates/readiness-report.md`.

Include:
1. All relevant flags with explanations.
2. Suggested improvements — including draft ACs in Given/When/Then format where ACs
   are missing or vague.
3. A 2-3 sentence summary assessment.

### Step 5 — Present and Confirm

Show the full report to the user in the conversation. Then ask:

> "Would you like me to post this as a comment on work item #[ID]?"

If the user confirms, use the **add comment** tool from the provider adapter to add the
readiness report as a comment on the work item. Format the comment appropriately:
- **ADO**: Convert markdown to HTML.
- **Jira**: Use markdown or ADF depending on MCP server support.
- **GitLab / GitHub**: Post markdown directly (native support).

If the user wants changes, iterate on the report before posting.

## Important

- Never modify the work item's Description or Acceptance Criteria fields directly.
  Only add comments.
- If the story is already well-formed, say so. Don't force flags where there are no issues.
  A report that says "this story looks ready" is a valid and valuable output.
- Do not invent business requirements. If something seems missing, flag it as a question,
  not an assertion about what should be there.
