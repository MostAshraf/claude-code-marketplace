# Prompt Context Templates

Standard context blocks the orchestrator inlines when constructing agent prompts in Phase 3 (`develop.md`), Phase 5 (`test.md`), Phase 6 (`create-pr.md`), and Phase 7 (`review-response.md`). Reference this file from each command instead of restating the templates inline.

The orchestrator pulls all field values from `.claude/context/language-config.md` (per-repo block) and the tracker's `Repo Status` section. It substitutes values per agent before launching.

---

## LANGUAGE_CTX

Include in **every** agent prompt. Omit irrelevant fields per agent role:

- **developer** — omit `Test command`
- **tester / reviewer** — omit `Format command`

```
LANGUAGE CONTEXT:
- Language: <language from language-config.md>
- Runtime: <runtime-version>
- Build command: <build-cmd>
- Restore command: <restore-cmd>           # developer / tester
- Test command: <test-cmd>                 # tester / reviewer
- Coverage command: <coverage-cmd>         # tester / reviewer (Phase 5)
- Coverage output: <coverage-path-pattern> # tester / reviewer (Phase 5)
- Format command: <format-cmd>             # developer only
- Test framework: <framework>              # tester only
- Conventions: Read .claude/context/conventions.md
```

## REPO_CTX

Include in **initial (non-rework)** agent launches. Omit when re-invoking in an existing worktree (use `WORKTREE_CTX` instead).

```
REPO CONTEXT:
- Repo: <repo-name>
- Repo path: <REPO_PATH>
- Feature branch: <FEATURE_BRANCH>
- Feature HEAD: <FEATURE_HEAD>
```

## WORKTREE_CTX

Include when **handing off or re-invoking** an agent in an existing worktree (e.g. tester → developer handoff, or rework after a Reviewer rejection). Replaces `REPO_CTX`.

```
WORKTREE DETAILS (do NOT create a new worktree):
- Worktree path: <from prior agent AGENT STATUS>
- Worktree branch: <from prior agent AGENT STATUS>
```

## CONTRACTS_CTX

Include when the plan has a **Contracts section** that names this repo as a producer or consumer. Skip otherwise.

```
CROSS-REPO CONTRACTS (if any — from the plan's Contracts section):
<Include any contracts where this repo is a producer or consumer.>
```
