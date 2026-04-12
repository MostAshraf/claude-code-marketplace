# Schema Upgrade & Legacy Migration

`/init-workspace` runs this pre-flight before [language discovery](language-discovery.md) to detect and offer upgrades for context files written by older versions of the harness.

## Migration Detection

Before running discovery, check whether `.claude/context/language-config.md` already exists. If it does, read it and look for the strings `Build adapter path`, `Test adapter path`, `Build adapter`, or `Test adapter`. If any of those appear, the file uses the legacy adapter-based schema. Print:

> "Your existing `language-config.md` uses the legacy adapter-based schema.
> The harness no longer reads static adapter files — all toolchain details are
> discovered at setup time and stored directly in `language-config.md`.
>
> I can:
>   [1] Re-run discovery now and regenerate `language-config.md` + `conventions.md`
>       (recommended — takes a minute per repo, requires a few confirmations)
>   [2] Keep legacy — perform an in-place schema upgrade by re-running discovery
>       with `/init-workspace --keep-legacy`, which preserves old decisions and
>       only fills in missing fields (regex patterns, coverage_format, etc.)
>
> Which would you like?"

## `--keep-legacy` semantics

Honour `--keep-legacy` when invoked with that flag:

- Skip [language discovery](language-discovery.md) Phase 3 negotiation entirely.
- Copy command strings forward from the old file (`build_command`, `test_command`, `coverage_command`, `format_command`, `restore_command`).
- Synthesise only the new fields the legacy schema lacked:
  - `build_error_pattern`, `build_warning_pattern`, `build_success_pattern`
  - `test_summary_pattern`
  - `coverage_format`
  - `zero_warning_support`
  - `permissions_requested`

This is the right path for users who carefully tuned commands in the old format and don't want to repeat the negotiation.

## Migration from `ado-config.md`

If a legacy `.claude/context/ado-config.md` exists (the pre-multi-provider configuration file):

1. Read its values (organization, project, area path, iteration path, hierarchy, custom fields).
2. Create `provider-config.md` with `Work Item Provider: ado` and `Git Provider: ado`.
3. Populate the ADO-specific fields from the legacy file.
4. Ask if the user wants to delete the old `ado-config.md` (recommend yes to avoid confusion).
