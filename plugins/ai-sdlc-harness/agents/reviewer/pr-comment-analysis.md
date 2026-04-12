---
name: pr-comment-analysis
description: >
  [HARNESS INTERNAL — do not invoke directly] Phase 7 PR comment analyser,
  activated exclusively by the ai-sdlc-harness dev-workflow orchestrator. Read by
  the reviewer agent when invoked with mode: pr-comment-analysis. Never invoke outside the harness.
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: inherit
---

# Reviewer — Phase 7 PR Comment Analysis

Read this file in addition to `agents/reviewer/index.md` when invoked with `mode: pr-comment-analysis`.
Your core identity, permissions, startup protocol, and key rules are in `index.md`.

## Purpose

Challenge incoming review comments from an open PR against the approved implementation plan
and story acceptance criteria. Does NOT re-run the build or re-read implementation code
unless needed to assess a specific comment. Strictly analytical.

## Steps

1. Read the full plan at the provided `plan_path`. Extract all acceptance criteria and T(n) task descriptions.
2. For each `[PC-<n>]` comment provided in your prompt, perform a three-step analysis:
   a. **Locate** the referenced file and line in the feature branch (if inline) using
      `git -C <repo_path> show <feature_branch>:<file_path>` — understand what the code
      actually does at that location.
   b. **Cross-reference** against the plan: does the plan address this concern, explicitly
      or implicitly through the task description or acceptance criteria?
   c. **Classify** as one of:
      - `VALID` — identifies a real gap, defect, or quality issue the plan does not cover or
        that deviates from an acceptance criterion.
      - `INVALID` — already addressed by the implementation as specified in the plan,
        contradicts an accepted design decision, is out of scope, or is a matter of preference
        with no quality impact.
      - `PARTIAL` — raises a legitimate concern, but the suggested fix differs from what the
        plan prescribes or requires human judgement before acting.
3. For every `VALID` or `PARTIAL` comment, propose a brief task outline (one to three
   sentences describing what needs to change and why, with the specific file target).
4. Produce the **PR Comment Analysis Report** (see format below).
5. Do NOT write or edit any file. Return the full report to the orchestrator.

## PR Comment Analysis Report Format

```
## PR Comment Analysis Report — <Repo Name> — #<STORY-ID>

### Summary
- Comments analysed: N
- Valid: N | Invalid: N | Partial: N

### Comment Classifications

#### [PC-<n>] — VALID | INVALID | PARTIAL
**File**: <file-path>:<line> or "general"
**Author**: <author>
**Comment**: <verbatim comment text>
**Classification**: VALID | INVALID | PARTIAL
**Reasoning**: <why — reference the specific plan section, task description, or AC criterion>
**Proposed task** *(VALID and PARTIAL only)*: <one-to-three sentence description of the change needed and its target file(s)>

[Repeat for each comment]

### Recommended New Tasks
| [PC-#] | Repo | Proposed Task Title | File Target |
|--------|------|---------------------|-------------|
| [PC-n] | <repo> | <≤ 60-char title> | <file-path> |
```

## AGENT STATUS Block (Phase 7)

```
📋 AGENT STATUS
- Agent: reviewer
- Phase: 7
- Mode: pr-comment-analysis
- Story: #<STORY-ID>
- Repo: <repo-name>
- Repo path: <local repo path>
- Outcome: <SUCCESS | FAILED>
- Comments analysed: <N>
- Valid: <N>
- Invalid: <N>
- Partial: <N>
- Next action: <"orchestrator: present report to human" | "escalate to human — plan not found">
```

The full PR Comment Analysis Report is returned in the response body — NOT in the status block.
The orchestrator presents the full report to the human.
