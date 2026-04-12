# Permissions Proposal (Step 3c)

After [language discovery](language-discovery.md) Phase 3 negotiate completes for **all repos**, `/init-workspace` proposes Bash permissions so the agents can run discovered commands without interactive prompts at runtime.

## Procedure

1. **Collate command heads.** For each repo, take the first whitespace-separated token of every command field: `restore_command`, `build_command`, `test_command`, `coverage_command`, `format_command`. Include wrapper scripts (`./mvnw`, `./gradlew`) as their own heads. For wrappers, use the bare wrapper name (e.g. `mvnw`, `gradlew`).

2. **Convert to `Bash(<cmd>:*)` format** and deduplicate across repos. Record which repos each command belongs to for the presentation.

3. **Present the proposal** to the user:

   ```
   I need to pre-approve these Bash commands so agents run them without
   prompting you during the workflow. Review and approve:

     [x] Bash(poetry:*)       — used for: build, test, coverage in AuthService
     [x] Bash(pytest:*)       — used for: test in AuthService
     [x] Bash(ruff:*)         — used for: format in AuthService
     [x] Bash(go:*)           — used for: build, test, format in PaymentGateway
     [x] Bash(./mvnw:*)       — used for: build, test in OrderService

   Type 'all' to approve, 'none' to skip (you'll be prompted at runtime),
   or a comma-separated list to approve specific commands.
   ```

4. **On approval, structured-edit `settings.json`:**
   - Read the JSON file.
   - Modify `permissions.allow` (an array): append each approved entry that is not already present. **Preserve all existing entries.** Do not rewrite the file as a string — round-trip through JSON parse/stringify.
   - Write the file back.

5. **Record the full proposed list** in `language-config.md:permissions_requested` for each repo (even if the user only approved a subset — the record reflects what was needed, not what was granted).

6. **Document the refresh flag.** Tell the user that `/init-workspace --refresh-permissions` re-proposes only Step 3c, without re-running language discovery.

7. **Session restart notice.** Tell the user:
   > "⚠️ I've updated `.claude/settings.json` with the new Bash permissions. Claude Code may not hot-reload permissions mid-session — please restart your session if you hit unexpected permission prompts during `/dev-workflow`."

## Fallback

If the user declines (`none`), they will hit interactive permission prompts at runtime. That's fine for foreground commands, but background agents can't prompt.

## Preflight Check

Phase 3 of `/dev-workflow` performs a preflight check that all required permissions (the `permissions_requested` list) are present in `settings.json` BEFORE launching any background agent lanes. Missing permissions cause a hard-fail with an actionable message ("run `/init-workspace --refresh-permissions` and restart your session"), not an interactive prompt — because background agents cannot prompt the user.
