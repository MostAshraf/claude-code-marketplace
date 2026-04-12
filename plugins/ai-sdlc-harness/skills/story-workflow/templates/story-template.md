# Story Template

This is the canonical format for user stories. All commands in this skill produce output
that follows this structure.

```markdown
## Context
[Why does this story exist? What business problem or user need does it address?
Include relevant background that helps developers understand the motivation.]

## Description
As a [persona], I want [capability], so that [outcome].

## Acceptance Criteria
- [ ] Given [precondition], When [action], Then [expected result]
- [ ] Given [precondition], When [action], Then [expected result]
- [ ] ...

## Out of Scope
[Explicitly what this story does NOT cover. Helps prevent scope creep and
sets clear boundaries for the implementation.]

## Open Questions
[Anything unresolved. Gets cleared during refinement or grooming sessions.
Remove items as they get answered — don't leave stale questions.]

## Technical Notes
[Added during or after grooming. Per-repo breakdown of affected components,
migration concerns, testing strategy, and risk flags. See technical-notes.md
for the detailed format.]
```

## Section Guidelines

**Context** — Write 2-4 sentences. Focus on the "why" not the "what." If a developer reads
only this section, they should understand the business motivation. Avoid implementation details here.

**Description** — One sentence in user story format. If the story needs multiple "As a..."
statements, it may be too large and should be split.

**Acceptance Criteria** — Each AC should be independently testable. Use Given/When/Then
format. Aim for 3-7 ACs per story. Fewer than 3 usually means missing edge cases. More
than 7 usually means the story is too large.

**Out of Scope** — List 1-3 items that someone might reasonably assume are included but
are not. This section prevents mid-sprint scope discussions. If nothing is ambiguous,
write "No explicit exclusions identified."

**Open Questions** — Prefix each with who needs to answer it: `[PO]`, `[Tech]`, or `[Team]`.
Example: `[PO] Should existing users be migrated automatically or opt-in?`

**Technical Notes** — Only populated during grooming. Left empty or absent before grooming.
See `technical-notes.md` for the per-repo format.
