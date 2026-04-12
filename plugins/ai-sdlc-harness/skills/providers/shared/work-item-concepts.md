# Work Item Concept Definitions

Canonical definitions for the generic concepts used in all provider Field Mapping tables.
Each provider's `work-items.md` maps these concepts to provider-specific fields.

## Concept Definitions

| Generic Concept | Meaning in This Workflow |
|---|---|
| Title | Short name of the story/issue — used in PR/MR titles and commit messages |
| Description | Narrative context for the story — the "why" and "what" |
| Acceptance Criteria | Testable conditions that must be true for the story to be Done. Read from a dedicated field or parsed from the Description (see below). |
| State | Current lifecycle status (open / in-progress / closed). Maps to workflow gates. |
| Area/Project | Team or domain owning the story. Used to route to the correct repo/team. |
| Sprint | Time-boxed iteration the story belongs to. |
| Story Points | Effort estimate. Used for sprint capacity planning. |
| Linked Items | Related stories, parent epics, or blocking issues. |

## Parsing Embedded Acceptance Criteria

When a provider has no dedicated AC field (GitHub, GitLab, Zoho, local-markdown), ACs are
embedded in the description. Apply these heuristics in order:

1. Look for a `## Acceptance Criteria` heading — extract all content in that section.
2. Look for a task list (`- [ ]` items) after the main prose — treat those items as ACs.
3. If neither is present, flag the gap and ask the user to identify AC items during the
   requirements clarification step.

During `init-workspace`, document which convention the team uses in `provider-config.md`
so subsequent runs don't need to re-discover it.
