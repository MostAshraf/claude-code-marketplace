# /story-improve Command

Single-pass story improvement. Assesses readiness internally, fills gaps conversationally,
and produces a refined story — all in one flow. Replaces the separate analyze-then-refine
workflow with a single adaptive command.

## Invocation

The user types `/story-improve [work-item-id]`. Optionally followed by session notes
(pasted text, bullet points, or a rough description of what was discussed in refinement).

This command is always human-invoked.

## Prerequisites

- `.claude/context/provider-config.md` must exist (run `/init-workspace` first).
- `.claude/context/repos-metadata.md` should exist (for domain context).
- Work item provider MCP tools must be available (as configured in `provider-config.md`).

## Behavior

### Step 1 — Fetch the Story

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

Read:
- `.claude/context/repos-metadata.md` — for domain landscape.
- `.claude/context/conventions.md` — for technical terminology alignment.
- `templates/story-template.md` — the target output format.
- `templates/readiness-report.md` — for the flag catalog (used as an internal rubric only).

### Step 3 — Assess Readiness (Internal)

Evaluate the story against the readiness dimensions from `templates/readiness-report.md`.

**Do NOT present this as a standalone readiness report.** Instead, use it to:
1. Classify the story into a tier (see below).
2. Identify the specific gaps that need user input.
3. Determine which questions to ask.

**Tier classification:**
- **Tier 1 — Solid.** At most 1-2 yellow flags and no red flags. The story is well-formed
  and can be drafted immediately with minimal or no questions.
- **Tier 2 — Some gaps.** 1-3 total issues (mix of red and yellow). Specific areas need
  clarification but the story has a solid foundation.
- **Tier 3 — Rough.** 4+ issues, or any critical section is entirely missing (no ACs,
  no description, no context). Needs more substantial input from the user.

### Step 4 — Conversational Gap-Filling

Based on the tier, adapt the interaction:

**Tier 1 — Story is already solid:**
Skip questions. Proceed directly to drafting. Briefly acknowledge what's good:
> "This story is in good shape — clear context, testable ACs, bounded scope.
> I'll draft a clean version in the template format."

**Tier 2 — Some specific gaps:**
Ask 2-5 targeted questions. Each question should:
- Reference the specific gap (not generic).
- Suggest an answer where possible (the user confirms or corrects — not drafting from scratch).
- Be answerable in 1-2 sentences.

Example:
> "The acceptance criteria say 'errors are handled gracefully' — this isn't testable
> as written. Should it be something like 'Given an invalid token, When login is
> attempted, Then a 401 with error code AUTH_INVALID_TOKEN is returned'? Or did the
> team discuss a different error behavior?"

Present all questions at once (up to 5). Don't drip-feed them one at a time.

**Tier 3 — Story is rough/sparse:**
Acknowledge the state honestly:
> "This story needs some work before I can draft a solid version. Let me ask a few
> questions to fill in the gaps."

Ask up to 5 questions in the first round. After getting answers, if critical gaps remain,
ask a second round (up to 3 more questions). Then draft.

**Using session notes:**
If the user provided session notes with the command, mine them thoroughly before asking
questions. Don't ask about things the notes already clarify. Acknowledge what you learned:
> "From your session notes, I see the team decided to limit scope to admin users only
> and defer the integration work. I'll incorporate that. A couple of remaining questions..."

If no session notes were provided and the story is Tier 2 or 3, ask:
> "Do you have any notes from a refinement session? Even rough bullet points help.
> If not, I'll work from what's in the work item."

### Step 5 — Draft the Complete Story

Using the answers from Step 4 (or the existing content for Tier 1 stories), draft the
ENTIRE story at once following `templates/story-template.md`.

Include all sections:
- **Context** — 2-4 sentences on the "why."
- **Description** — As a [persona], I want [capability], so that [outcome].
- **Acceptance Criteria** — Given/When/Then checklist. Happy path first, then error/edge cases.
- **Out of Scope** — Explicit exclusions. Use session notes and story context to identify these.
- **Open Questions** — Unresolved items tagged with `[PO]`, `[Tech]`, or `[Team]`.
- **Technical Notes** — Leave empty. Populated by `/story-groom`.

**Readiness Summary header (optional):**
If meaningful improvements were made (Tier 2 or 3), prepend a brief summary of what changed:

```
### What was improved
- Added 3 missing error-case ACs
- Clarified persona from "user" to "platform administrator"
- Added explicit out-of-scope boundaries

---
```

Skip this header for Tier 1 stories where the content is largely unchanged.

### Step 6 — Review and Iterate

Present the complete draft:
> "Here's the improved story. Review the whole thing — I can adjust any section."

The user may:
- Approve as-is.
- Request changes to specific sections.
- Add, remove, or modify ACs.
- Adjust scope or context.

Iterate until the user is satisfied. After minor edits, don't re-present the entire story
unless the user asks — just confirm the change and ask if there's anything else.

If during review you notice the story might be too large (>7 ACs, multiple capabilities),
gently suggest splitting:
> "This story has 9 acceptance criteria spanning two distinct capabilities. Would it be
> cleaner as two stories?"

### Step 7 — Post to ADO

After the user approves the final version, ask:
> "Ready to post this as a comment on work item #[ID]?"

If confirmed, use `the **add comment** tool from the active provider adapter` to add the improved story
as a single comment on the work item. Format as clean HTML for ADO's comment renderer.

**Provider-specific formatting notes:**
- **ADO**: Format as HTML for ADO's comment renderer.
- **Jira**: Format as markdown or ADF depending on MCP server support.
- **GitLab / GitHub**: Format as markdown (native support).

The comment contains:
1. The "What was improved" summary (if present).
2. The complete story in template format.

## Important

- **Never modify** the work item's Description or Acceptance Criteria fields directly.
  Only add comments.
- **Adapt, don't interrogate.** The adaptive behavior is the core value. If the story is
  good, say so and draft fast. Don't ask unnecessary questions.
- **Suggest answers.** When asking questions, propose an answer the user can confirm or
  correct. The user should be validating, not drafting from scratch.
- **Mirror terminology.** Maintain the user's domain language. If they call something a
  "platform," don't rename it to "system."
- **Session notes are gold.** If provided, mine them thoroughly before asking questions
  the notes might already answer.
- **Don't invent requirements.** If something seems missing, flag it as a question, not
  an assertion about what should be there.
- **One comment, one artifact.** The entire output goes into a single ADO comment — not
  multiple comments for different sections.
