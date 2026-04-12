---
name: coverage-report
description: >
  Run tests with code coverage collection, parse the results, and present a formatted
  coverage report — any language, discovery-driven. Dispatches by coverage_format
  from .claude/context/language-config.md. Supports cobertura, jacoco, lcov,
  json-summary, and go-cover. Highlights pass/fail against the configured threshold
  (default 90%). Read-only analysis.
allowed-tools: Bash, Read, Grep, Glob
argument-hint: "[repo-name-or-path]"
---

# /coverage-report — Code Coverage Report (Language-Agnostic)

**Usage:** `/coverage-report [repo-name-or-path]`

Runs the repo's configured coverage command, locates the output file, dispatches
parsing based on `coverage_format`, and produces a structured coverage report.
No per-language logic lives in this skill — everything comes from discovered config.

## Pre-Flight: Resolve Target Repo

1. Read `.claude/context/language-config.md`.
2. Resolve the target repo via `$ARGUMENTS[0]` (repo name or path) or auto-detect
   from the current working directory.
3. From the matched entry, extract:
   - `project_root`
   - `coverage_command`
   - `coverage_format` — one of: `cobertura`, `jacoco`, `lcov`, `json-summary`,
     `go-cover`, `none`
   - `coverage_output_glob`
   - `coverage_threshold` (integer percentage; default 90 if missing)

4. **Early exit:** if `coverage_format == "none"`, print:
   ```
   Coverage checks disabled for this repo (coverage_format: none).
   ```
   and exit cleanly with no further action.

## Arguments

- `$ARGUMENTS[0]` (optional): Repo name or path. If omitted, auto-detect.

## Steps

### 1. Run Tests with Coverage

```bash
cd <project_root> && <coverage_command> 2>&1
```

Capture the exit code. If the command fails, still proceed to locate and parse
any coverage output that was produced, and flag the test failures in the report.

### 2. Locate Coverage File

```bash
find <project_root> -path <coverage_output_glob> -type f 2>/dev/null \
  | sort -r | head -1
```

Or, if `coverage_output_glob` is a plain glob (not a `find -path` expression):

```bash
ls -t <project_root>/<coverage_output_glob> 2>/dev/null | head -1
```

If no file is found, report the glob and instruct the user to re-check
`coverage_output_glob` in `language-config.md`. Stop.

### 3. Parse Coverage Data (Format Dispatch)

Dispatch on `coverage_format`. Each parser produces at minimum `line_pct` (float,
0–100). Some parsers also produce per-package / per-class breakdowns.

Prefer shell tooling (`xmllint`, `grep`, `awk`) over inline Python when possible.
Python is a **soft prerequisite** — fall back to Python only if `xmllint` is not
available and the format requires XML parsing.

#### Parser: `cobertura`

Used by: dotnet (Coverlet), Python (coverage.py), Ruby (SimpleCov), PHP (PHPUnit).

The root `<coverage>` element carries `line-rate` as a float in `[0.0, 1.0]`.

```bash
# Preferred: xmllint
LINE_RATE=$(xmllint --xpath 'string(/coverage/@line-rate)' <file>)
LINE_PCT=$(awk "BEGIN { printf \"%.1f\", ${LINE_RATE} * 100 }")

# Fallback: grep
LINE_RATE=$(grep -oE 'line-rate="[0-9.]+"' <file> | head -1 \
            | grep -oE '[0-9.]+')
LINE_PCT=$(awk "BEGIN { printf \"%.1f\", ${LINE_RATE} * 100 }")
```

For per-package breakdown, iterate `<package>` elements and read each `line-rate`.

#### Parser: `jacoco`

Used by: Java (Maven/Gradle with JaCoCo plugin).

The root element (`<report>`) contains a direct-child `<counter type="LINE" missed="M" covered="C"/>`.

```bash
# Preferred: xmllint
MISSED=$(xmllint --xpath 'string(/report/counter[@type="LINE"]/@missed)' <file>)
COVERED=$(xmllint --xpath 'string(/report/counter[@type="LINE"]/@covered)' <file>)
LINE_PCT=$(awk "BEGIN { t = ${MISSED} + ${COVERED}; if (t>0) printf \"%.1f\", ${COVERED}/t*100; else print \"0.0\" }")
```

Per-package: iterate `<package>` elements and read each direct-child
`<counter type="LINE">` (skip nested counters inside classes/methods — take only the
direct children).

#### Parser: `lcov`

Used by: JS/TS (Istanbul lcov reporter), Rust (tarpaulin), C/C++ (gcov/lcov).

Parse `LF:N` (lines found) and `LH:N` (lines hit) lines. Sum across all records.

```bash
TOTAL_LF=$(grep -E '^LF:' <file> | awk -F: '{ sum += $2 } END { print sum+0 }')
TOTAL_LH=$(grep -E '^LH:' <file> | awk -F: '{ sum += $2 } END { print sum+0 }')
LINE_PCT=$(awk "BEGIN { if (${TOTAL_LF}>0) printf \"%.1f\", ${TOTAL_LH}/${TOTAL_LF}*100; else print \"0.0\" }")
```

Per-file: each `SF:<path>` record is followed by its own `LF`/`LH` — extract
per-record for breakdown.

#### Parser: `json-summary`

Used by: Jest, Vitest, Istanbul (`--coverage-reporter=json-summary`).

Read `total.lines.pct` from the JSON file.

```bash
# Preferred: jq
LINE_PCT=$(jq -r '.total.lines.pct' <file>)

# Fallback: grep (brittle)
LINE_PCT=$(grep -oE '"lines":\{[^}]*"pct":[0-9.]+' <file> | head -1 \
           | grep -oE '[0-9.]+$')
```

Per-file breakdown: iterate keys of the top-level object (skip `"total"`) and
read `<file>.lines.pct`.

#### Parser: `go-cover`

Used by: Go (`go test -coverprofile=<file>`).

The output file is a Go coverprofile. Run `go tool cover -func=<file>` and extract
the `total:` line's percentage:

```bash
cd <project_root> && go tool cover -func=<file> 2>&1 \
  | awk '/^total:/ { gsub("%","",$NF); print $NF }'
```

Per-package breakdown: the same `go tool cover -func` output lists per-function
coverage; aggregate by package (everything before the last `/`).

#### Parser: unknown

If `coverage_format` is anything other than the five above (and not `none`), fail
loudly:

```
Unknown coverage format '<format>'; supported formats:
  cobertura, jacoco, lcov, json-summary, go-cover.
Update coverage_format in .claude/context/language-config.md
or set coverage_format=none to skip coverage checks.
```

Stop — do not attempt generic parsing.

### 4. Compare Against Threshold

```bash
THRESHOLD=<coverage_threshold>   # default 90
PASS=$(awk "BEGIN { print (${LINE_PCT} >= ${THRESHOLD}) ? \"PASS\" : \"FAIL\" }")
```

### 5. Present Report

```
╔══════════════════════════════════════════════════════════════╗
║                  CODE COVERAGE REPORT                        ║
╚══════════════════════════════════════════════════════════════╝

Generated:   <timestamp>
Repo:        <repo-name>
Language:    <language>
Format:      <coverage_format>
Source:      <path-to-parsed-file>
Test result: <PASSED | X FAILED>

─── Overall Coverage ──────────────────────────────────────────
  Line coverage:  XX.X%   <PASS | FAIL (threshold: <threshold>%)>
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  [████████████░░░] XX.X%

─── Per-Package / Per-Module Breakdown ───────────────────────
  <name>                 95.2%  PASS
  <name>                 87.1%  FAIL (below <threshold>%)
  <name>                 91.4%  PASS

─── Units Below Threshold ────────────────────────────────────
  <if any: list the specific packages/classes/files that need more coverage>

─── Recommendations ───────────────────────────────────────────
  <If below threshold: list specific units to improve>
  <If at/above threshold: "Coverage meets the <threshold>% threshold.">
───────────────────────────────────────────────────────────────
```

### 6. Cleanup

Do not delete coverage output files automatically — they live inside the repo's
build output directory, and the user may want to inspect them. If a prior run left
a known temporary directory (`./coverage-results` from dotnet/Coverlet defaults),
the repo's own `.gitignore` should cover it.

## Threshold

The default threshold is **90%** line coverage. The repo's `coverage_threshold`
field overrides this. The report clearly marks whether the threshold is met. If
below, list the top uncovered units to guide the Tester agent.

## Rules

- This skill is **read-only analysis** — it does NOT modify source or test code.
- Never hardcode language-specific logic (`dotnet`, `mvnw`, `jacoco`, `coverlet`, etc.).
  All commands and formats come from `language-config.md`.
- If tests fail, report both the test failures AND the coverage data.
- If coverage collection fails entirely, provide clear diagnostic steps pointing at
  `coverage_command`, `coverage_format`, and `coverage_output_glob` in the config.
- Prefer shell + `xmllint`/`jq`/`awk` over inline Python. Python is a **soft
  prerequisite** — only fall back to it when the preferred tool is unavailable.
- If `coverage_format == "none"`, exit cleanly with an informational message.
