# Language Discovery (Step 3b)

This is the read-only, four-phase pipeline that `/init-workspace` runs against each logical repo to discover its toolchain dynamically and write a single authoritative `language-config.md`. It replaces the old hard-coded .NET / Java detection.

> **Discovery is strictly read-only.** Never run `poetry install`, `npm install`, `dotnet restore`, `go mod download`, or any other command that touches the environment, network, or dependency tree. Only static file inspection and LLM inference are allowed. If a required detail cannot be determined without running a command, surface it as a negotiation question in Phase 3.

The migration / `--keep-legacy` flow that runs before Phase 1 is documented in [`schema-upgrade.md`](schema-upgrade.md).

## Phase 1 — Detect (file scan, depth ≤ 4)

For each logical repo in `repos-paths.md`, walk the filesystem to depth 4 and record which marker files are present. Record the **relative path** of each hit so the evidence is auditable.

**Backend markers:**
`pyproject.toml`, `setup.py`, `requirements.txt`, `Pipfile`, `poetry.lock`, `go.mod`, `Cargo.toml`, `pom.xml`, `build.gradle`, `build.gradle.kts`, `*.csproj`, `*.sln`, `*.fsproj`, `Gemfile`, `mix.exs`, `composer.json`, `CMakeLists.txt`, `Makefile`

**Frontend markers:**
`package.json`, `tsconfig.json`, `next.config.*`, `vite.config.*`, `webpack.config.*`, `angular.json`, `nuxt.config.*`, `svelte.config.*`, `remix.config.*`, `astro.config.*`, `tailwind.config.*`, `deno.json`, `bun.lockb`

**Lint/format markers:**
`.editorconfig`, `.prettierrc*`, `.eslintrc*`, `.rubocop.yml`, `ruff.toml`, `.flake8`, `rustfmt.toml`, `.clang-format`, plus `[tool.*]` sections inside `pyproject.toml`

**Coverage markers:**
`.coveragerc`, `jest.config.*`, `vitest.config.*`, `phpunit.xml`, `pyproject.toml:[tool.coverage]`, JaCoCo plugin in `pom.xml`, `coverlet.collector` in `.csproj`

**Wrapper scripts:** `mvnw`, `mvnw.cmd`, `gradlew`, `gradlew.bat`

**Lock files:** `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `Pipfile.lock`, `go.sum`, `Cargo.lock`, `Gemfile.lock`, `composer.lock`

**Test directory markers:** `tests/`, `test/`, `spec/`, `__tests__/`, `e2e/`

**Output:** an **evidence map per repo** — a structured list of `{marker, path}` entries. No inference yet. Do not read file contents (except enough to confirm marker type, e.g. confirming a `*.csproj` is XML).

## Phase 2 — Infer

For each repo, read the evidence map and a targeted sample of file contents (e.g. the first `.csproj` or `pyproject.toml` to extract runtime versions). Propose:

- **language** (free-form, e.g. `python`, `typescript`, `rust`, `dotnet`, `go`, `java`)
- **runtime_version** (e.g. `3.12`, `20`, `1.78`, `net10.0`, `1.22`, `21`)
- **Commands:** `restore_command`, `build_command`, `test_command`, `coverage_command`, `format_command` (the `format_command` must include `{FILE}` and `{PROJECT_ROOT}` placeholders — the auto-format hook substitutes them at runtime)
- **coverage_format:** one of `cobertura`, `jacoco`, `lcov`, `json-summary`, `go-cover`, `none`
- **Regex patterns** for parsing build/test output:
  - `build_error_pattern`
  - `build_warning_pattern`
  - `build_success_pattern`
  - `test_summary_pattern`
- **Framework signals** (FastAPI, Spring Boot, MediatR, Next.js, NestJS, Gin, Rails, ...)
- **Architecture signals** (layered, hexagonal, MVC, feature-folder, modules)
- **Naming conventions** — sample 20 random source files in the repo. Detect filename casing (`snake_case`, `camelCase`, `PascalCase`, `kebab-case`) and symbol casing from a quick scan of their contents. Record both file and symbol conventions.
- **test_framework** (pytest, xunit, junit5, vitest, jest, playwright, go test, ...)
- **test_file_pattern** (regex, e.g. `.*_test\\.go$`, `test_.*\\.py$`, `.*\\.spec\\.ts$`)
- **zero_warning_support:** one of `native`, `linter-based`, `none`
  - `native` — the compiler/build tool has a warnings-as-errors flag the build already uses or trivially can (e.g. `dotnet build -warnaserror`, `go vet`, `-Werror`)
  - `linter-based` — enforcement comes from a linter with a strict mode (e.g. `ruff`, `eslint --max-warnings=0`, `mypy --strict`, `clippy -D warnings`)
  - `none` — no mechanism detected

## Phase 3 — Negotiate (mandatory; human confirmation required)

**Always require human confirmation.** There is no `--ci` or non-interactive mode. Present findings per repo in a compact table and ask targeted questions for gaps or ambiguities. Questions are batched per repo.

Example presentation:

```
Detected for AuthService:
  Language:        python 3.12
  Build:           poetry run python -m compileall src
  Test:            poetry run pytest
  Coverage:        poetry run pytest --cov=src --cov-report=xml
  Coverage format: cobertura
  Format:          poetry run ruff format {FILE}
  Framework:       FastAPI
  Architecture:    layered
  Naming:          snake_case files, PascalCase classes
  Test framework:  pytest
  Test pattern:    test_.*\.py$
```

Generate questions **dynamically** based on what is missing, ambiguous, or worth confirming. Examples:

1. **Strict type checking** — if no strict type checker is configured, ask:
   > "No strict type checker detected. Add `mypy --strict` / `tsc --strict` / `ruff --select=ALL` to the build?"
2. **Architecture enforcement** — if a framework was detected, ask what architecture rules should be enforced in review (e.g. "FastAPI + layered suggests ports/adapters — enforce 'no DB imports in api/' in review checks?").
3. **Naming conventions** — if there is no `.editorconfig` or equivalent, ask whether to infer naming from existing code (risks codifying inconsistencies), use tool defaults, or leave unspecified.
4. **Coverage threshold** — confirm the 90% default.
5. **Zero-warning policy** — if `zero_warning_support == "none"`, surface the warning below with three options and record the user's choice.

**Zero-warning warning (only when support is `none`):**

```
⚠️  No warnings-as-errors equivalent detected for <language> in <repo>.
    Options:
      [1] Add <linter> --strict to the build (recommended)
      [2] Accept — rely on Reviewer to catch quality issues manually
      [3] Pick a specific linter
```

Record the user's selection in `language-config.md` as part of the repo's `zero_warning_support` entry. Option [1] must update the `build_command` to include the strict linter invocation.

Nothing in Phase 3 is assumed — every answer is the human's to give.

## Phase 4 — Write

Produce `.claude/context/language-config.md` using the schema below, and `.claude/context/conventions.md` using the schema in [`SKILL.md`](SKILL.md) Step 4. Both files are fully materialised from the negotiated output — no references to external adapter files.

---

## `language-config.md` schema

This is the full schema written to `.claude/context/language-config.md`. Every field is mandatory unless marked `optional`. There is one `### <repo-name>` block per logical repo in `repos-paths.md`.

```markdown
# Language Configuration
<!-- generated by /init-workspace — do not edit by hand; re-run --refresh to regenerate -->

## Repos
| Repo | Language | Runtime | Project Root Marker |
|------|----------|---------|---------------------|
| <repo-name>  | <language> | <runtime-version> | <primary marker filename> |

## Per-Repo Details

### <repo-name>
- language: <free-form, e.g. python, typescript, rust, dotnet, go, java>
- runtime_version: <e.g. 3.12, 20, 1.78, net10.0, 1.22, 21>
- project_root: <absolute path>
- project_root_markers: [".csproj", "pom.xml", "package.json", "go.mod", ...]
- file_extensions: [".cs", ".csx"]
- restore_command: "<cmd>"                               # optional
- build_command: "<cmd>"
- build_zero_warning_flag: "<flag or empty>"
- zero_warning_support: "native" | "linter-based" | "none"
- build_error_pattern: "<regex>"
- build_warning_pattern: "<regex>"
- build_success_pattern: "<regex>"
- test_command: "<cmd>"
- test_summary_pattern: "<regex>"
- coverage_command: "<cmd>"
- coverage_format: "cobertura | jacoco | lcov | json-summary | go-cover | none"
- coverage_output_glob: "<glob>"
- coverage_threshold: 90
- format_command: "<cmd with {FILE} and {PROJECT_ROOT} placeholders>"
- test_framework: "<e.g. pytest, xunit, junit5, vitest, playwright, go test>"
- test_file_pattern: "<regex>"
- permissions_requested: ["Bash(poetry:*)", "Bash(pytest:*)", ...]
```

**Notes:**
- `format_command` must include `{FILE}` and `{PROJECT_ROOT}` placeholders — the auto-format hook substitutes them at runtime.
- `coverage_format: none` disables coverage enforcement entirely for that repo.
- `zero_warning_support: none` means the user has accepted that no tool-enforced strictness exists; the Reviewer compensates manually.
- `permissions_requested` records what was needed. What was actually granted lives in `settings.json:permissions.allow` — see [`permissions.md`](permissions.md).
