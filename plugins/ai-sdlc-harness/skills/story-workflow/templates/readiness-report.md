# Readiness Report Template

This is the output format for `/story-analyze`. It provides a qualitative assessment of
story readiness with actionable flags.

```markdown
## Story Readiness Report
**Work Item:** #[ID] — [Title]
**Assessed:** [date]

### Flags

🔴 **[Flag Name]**
[Explanation of what's missing or problematic, with a specific suggestion for improvement.]

🟡 **[Flag Name]**
[Explanation of a concern that isn't blocking but should be addressed.]

🟢 **[Flag Name]**
[Acknowledgment of something done well — reinforces good practices.]

### Suggested Improvements

[Concrete, actionable suggestions. Not generic advice — specific to this story.
May include draft acceptance criteria, proposed scope boundaries, or questions
that should be raised in the refinement session.]

### Summary

[2-3 sentence overall assessment. Is this story ready for refinement discussion,
or does it need pre-work from the PO first?]
```

## Flag Catalog

These are the readiness dimensions to evaluate. Not every flag applies to every story —
use judgment about which are relevant.

**Context & Motivation**
- 🔴 Missing Context — No explanation of why this story exists.
- 🟡 Vague Context — Context is present but doesn't clearly connect to a business need.
- 🟢 Clear Context — Business motivation is well articulated.

**Description Quality**
- 🔴 No User Story Format — Description doesn't identify persona, capability, or outcome.
- 🟡 Ambiguous Persona — "As a user" is too generic; should specify which type of user.
- 🟢 Well-Formed Description — Clear persona, capability, and outcome.

**Acceptance Criteria**
- 🔴 Missing ACs — No acceptance criteria at all.
- 🔴 Untestable ACs — ACs are vague ("system should work well") or not verifiable.
- 🟡 Incomplete ACs — Some ACs exist but obvious scenarios are missing (error cases, edge cases).
- 🟡 Too Many ACs — More than 7 ACs suggests the story may need splitting.
- 🟢 Solid ACs — Testable, specific, and covering the main scenarios.

**Scope**
- 🔴 Unbounded Scope — No clear boundaries; could expand indefinitely.
- 🟡 Implicit Assumptions — Story assumes context that isn't written down.
- 🟡 No Out of Scope — Nothing explicitly excluded; scope creep risk.
- 🟢 Well-Bounded — Clear what's in and what's out.

**Dependencies & Risks**
- 🟡 Implicit Dependencies — Story depends on another story or system but doesn't say so.
- 🟡 Cross-Team Dependency — Requires work from another team; coordination needed.
- 🟢 Self-Contained — No external dependencies identified.

## Tone

The readiness report should be constructive and specific. Avoid generic criticism.
Every red or yellow flag must include a concrete suggestion for how to fix it.
Green flags are important too — they reinforce what the PO and team are doing well.
