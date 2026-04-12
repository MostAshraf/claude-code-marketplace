# /story-refine Command

> **Note:** For most workflows, `/story-improve` is the recommended alternative — it combines
> readiness analysis with refinement in a single adaptive flow. `/story-refine` remains
> available when you specifically want the slower, section-by-section interactive refinement
> for complex or contentious stories.

Interactive post-refinement story structuring. Takes a story and optional session notes,
then restructures the story into the canonical template through a collaborative conversation.

## Invocation

The user types `/story-refine [work-item-id]`. Optionally followed by session notes
(pasted text, bullet points, or a rough description of what was discussed).

This command is always human-invoked.

## Prerequisites

- `.claude/context/provider-config.md` must exist (run `/init-workspace` first).
- `.claude/context/repos-metadata.md` should exist (for domain context).
- Work item provider MCP tools must be available (as configured in `provider-config.md`).

## Behavior

### Step 1 — Read the Story

Read `.claude/context/provider-config.md` to determine the active work item provider.
Read the matching adapter from `skills/providers/<provider>/work-items.md`.

Use the **fetch work item** tool from the provider adapter to fetch the work item by ID. Extract the current
title, description, acceptance criteria, state, and linked items — same as `/story-analyze`.

### Step 2 — Gather Session Notes

If the user provided session notes along with the command, use them. If not, ask:

> "Do you have any notes from the refinement session? This could be bullet points, rough
> notes, or just a description of what was discussed. If not, I'll work from what's
> currently in the work item."

Session notes are valuable because they capture context that didn't make it into the work
item — PO clarifications, scope decisions, rejected approaches, etc.

### Step 3 — Load Context

Read:
- `templates/story-template.md` — the target format.
- `.claude/context/repos-metadata.md` — for domain context.
- `.claude/context/conventions.md` — for technical terminology alignment.

### Step 4 — Interactive Refinement

Work through the story template **section by section**, proposing content for each and
getting the user's approval before moving on.

**Context section:**
- Draft a Context paragraph based on the existing description and session notes.
- Present it and ask: "Does this capture the business motivation correctly?"
- Iterate if the user has corrections.

**Description section:**
- Formulate the user story statement (As a... I want... So that...).
- If the existing description contains multiple capabilities, flag this:
  > "This looks like it might cover multiple capabilities. Should we split this into
  > separate stories, or is this one coherent unit of work?"
- Get confirmation.

**Acceptance Criteria:**
- Draft Given/When/Then ACs based on the existing criteria, session notes, and your
  understanding of the domain.
- Cover the happy path first, then error cases and edge cases.
- Present all ACs together and ask: "Are these complete? Any scenarios missing?"
- Iterate. The user may add, remove, or modify ACs.

**Out of Scope:**
- Based on the session notes and your understanding, propose what's explicitly excluded.
- If session notes mention things like "we decided not to include X" or "that's for a
  future sprint," capture those here.
- Ask: "Anything else that should be explicitly excluded?"

**Open Questions:**
- Collect any unresolved items from the session notes.
- Flag anything you noticed during refinement that seems ambiguous.
- Tag each question with who should answer it: `[PO]`, `[Tech]`, or `[Team]`.
- Ask: "Any other open questions from the session?"

**Technical Notes:**
- Leave this section empty or absent. It gets populated during `/story-groom`.
- If the user volunteers technical context during refinement, note it but clarify:
  > "I'll note this for now, but the full technical analysis happens during `/story-groom`."

### Step 5 — Assemble and Review

Once all sections are confirmed, assemble the complete story and present it as a whole:

> "Here's the complete refined story. Please review the full picture before I post it."

Show the entire story in the template format.

### Step 6 — Post to ADO

After the user approves the final version, ask:

> "Ready to post this as a comment on work item #[ID]?"

If confirmed, use the **add comment** tool from the provider adapter to add the refined story
as a comment on the work item. Format appropriately for the provider (HTML for ADO, markdown
for GitLab/GitHub, ADF/markdown for Jira).

## Important

- Never modify the work item's Description or Acceptance Criteria fields directly.
  Only add comments.
- The interactive nature of this command is its core value. Don't rush through sections.
  Give the user space to think and correct.
- If the user provides very sparse session notes, do your best with what's available
  but be transparent about assumptions: "I'm inferring X from the description — is that
  correct?"
- Maintain the user's domain language. If they call something a "platform" don't rename
  it to "system." Mirror their terminology.
- If during refinement you notice the story might be too large (many ACs, broad scope),
  gently suggest splitting: "This story has 9 acceptance criteria spanning two distinct
  capabilities. Would it be cleaner as two stories?"
