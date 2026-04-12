---
name: validate-build
description: >
  Standalone build and test validation — any language, discovery-driven. Reads
  .claude/context/language-config.md for the target repo and runs the configured
  restore, build, and test commands, parsing output via the repo's configured
  regex patterns. Reports results in a structured format with pass/fail status.
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[repo-name-or-path]"
---

# /validate-build — Build & Test Validation (Language-Agnostic)

**Usage:** `/validate-build [repo-name-or-path]`

Runs a full build and test validation cycle against a repo by reading its entry in
`.claude/context/language-config.md`. No per-language logic lives in this skill —
everything comes from discovered configuration.

## Pre-Flight: Resolve Target Repo

1. Read `.claude/context/language-config.md`.
2. Resolve the target repo:
   - If `$ARGUMENTS[0]` matches a repo name in the config, use that entry.
   - Else if `$ARGUMENTS[0]` is a path, match it against each repo's `project_root`.
   - Else, auto-detect from the current working directory by walking up to find a
     matching `project_root`.
3. If no match, report clearly and stop.
4. From the matched entry, extract:
   - `project_root`
   - `restore_command` (optional — may be empty)
   - `build_command`
   - `build_zero_warning_flag` (optional)
   - `zero_warning_support` (`native` | `linter-based` | `none`)
   - `build_error_pattern` (regex)
   - `build_warning_pattern` (regex)
   - `build_success_pattern` (regex)
   - `test_command`
   - `test_summary_pattern` (regex)

If any required field is missing, report the missing field and stop — the user
needs to re-run `/init-workspace` to regenerate the config.

## Arguments

- `$ARGUMENTS[0]` (optional): Repo name (from language-config.md) or a path.
  If omitted, auto-detect from the current directory.

## Steps

All commands run from `project_root` unless the configured command already embeds a
`cd`. Use `cd <project_root> && <cmd>` when invoking via Bash.

### 1. Restore Dependencies

If `restore_command` is set and non-empty, run it:

```bash
cd <project_root> && <restore_command> 2>&1
```

If empty, skip this step silently. If the restore command fails, record the error
and continue to the build step so the user gets a complete picture.

### 2. Build

Compose the build command. If `zero_warning_support == "native"` and
`build_zero_warning_flag` is non-empty, append the flag to the build command:

```bash
cd <project_root> && <build_command> <build_zero_warning_flag> 2>&1
```

Otherwise, run the build command as-is:

```bash
cd <project_root> && <build_command> 2>&1
```

Parse the combined stdout/stderr output:
- Count matches of `build_error_pattern` → error count, capture top 10 for the report.
- Count matches of `build_warning_pattern` → warning count, capture top 10.
- Presence of `build_success_pattern` → success signal (used alongside the error count
  and the process exit code).

**Zero-warning handling:**
- `zero_warning_support == "native"`: warnings are promoted to errors via the flag;
  any warning is a build failure.
- `zero_warning_support == "linter-based"`: run the build; treat non-zero warning
  counts as failures only if the configured linter step is part of the build command.
- `zero_warning_support == "none"`: report the following banner in the final output:
  ```
  ⚠️ Zero-warning enforcement not configured for this repo
     (zero_warning_support: none). Reviewer must verify quality manually.
  ```
  Do not treat warnings as failures in this mode; still report the count.

### 3. Run Tests

```bash
cd <project_root> && <test_command> 2>&1
```

Parse the output using `test_summary_pattern`. The regex is expected to capture
named groups where possible: `total`, `passed`, `failed`, `skipped`. If the regex
is positional, rely on the configured capture order. Combine parsed results with
the process exit code to determine pass/fail.

### 4. Present Report

```
╔══════════════════════════════════════════════════════════════╗
║                  BUILD & TEST VALIDATION                     ║
╚══════════════════════════════════════════════════════════════╝

Timestamp:    <YYYY-MM-DD HH:MM UTC>
Repo:         <repo-name>
Project root: <project_root>
Language:     <language>  (runtime: <runtime_version>)

─── Restore ───────────────────────────────────────────────────
  Status: SUCCESS | FAILED | SKIPPED (no restore_command configured)
  <if failed: error details>

─── Build ─────────────────────────────────────────────────────
  Command:  <build_command> [<zero_warning_flag>]
  Status:   SUCCESS (0 errors, 0 warnings)
          | FAILED  (<N> errors, <M> warnings)
  Zero-warning policy: <native | linter-based | none>

  <if errors, list top 10 matches of build_error_pattern>
  Errors:
    <match 1>
    ...

  <if warnings, list top 10 matches of build_warning_pattern>
  Warnings:
    <match 1>
    ...

  <if zero_warning_support == "none":>
  ⚠️ Zero-warning enforcement not configured for this repo
     (zero_warning_support: none). Reviewer must verify quality manually.

─── Tests ─────────────────────────────────────────────────────
  Command: <test_command>
  Status:  PASSED | FAILED
  Total:   <count>
  Passed:  <count>
  Failed:  <count>
  Skipped: <count>

  <if failures, list each failing test captured from output (top 5)>

─── Summary ───────────────────────────────────────────────────
  Overall: READY FOR PR  |  NOT READY

  <If not ready, list specific action items>
───────────────────────────────────────────────────────────────
```

### 5. Overall Verdict

The build is **READY** only if ALL of:
- Restore succeeded (or was skipped because no `restore_command` is configured)
- Build exited zero AND error count from `build_error_pattern` is zero
- For `zero_warning_support == "native"`, warning count is zero (warnings are errors
  under the flag, so this is implied by the error check)
- Tests exited zero AND parsed failure count is zero

Otherwise it is **NOT READY** with specific action items listed.

## Rules

- This skill is **read-only analysis** — it does NOT modify code.
- Always run the full pipeline (restore → build → test) even if an earlier step fails.
- Never hardcode language-specific commands (`dotnet`, `mvnw`, `gradle`, `pytest`, etc.)
  in this skill. All commands come from `language-config.md`.
- If `language-config.md` is missing or has no entry for the target repo, report
  clearly and instruct the user to run `/init-workspace`.
- Truncate verbose output (show top 10 errors/warnings, top 5 failed tests). Mention
  if more exist.
