# Technical Notes Template

This is the output format for the Technical Notes section produced by `/story-groom`.
It provides a per-repo breakdown of technical impact.

```markdown
## Technical Notes

### [repo-name]
- **Affected Components:** [List specific files, classes, services, or modules that need changes]
- **What Changes:** [Brief description of the changes needed in this repo]
- **Database/Migration:** [Any schema changes, EF Core migrations, or data migrations needed. "None" if not applicable]
- **API Contract:** [Any new or changed endpoints, request/response models. "None" if not applicable]
- **Testing Strategy:** [What types of tests are needed — unit, integration, E2E. Mention specific areas to cover]
- **Risk:** [Low / Medium / High — with a brief explanation of why]

### [another-repo-name]
- **Affected Components:** ...
- **What Changes:** ...
- **Database/Migration:** ...
- **API Contract:** ...
- **Testing Strategy:** ...
- **Risk:** ...

### Cross-Repo Considerations
[Only include this section if the story spans multiple repos.
Describe coordination concerns: deployment order, shared contracts,
feature flags needed for safe rollout, etc.]
```

## Guidelines

**Affected Components** — Be specific. Name the actual classes, services, or config files.
"The auth module" is too vague. `AuthenticationService.cs`, `SamlConfigurationProvider.cs`
is useful.

**What Changes** — One to three sentences. Describe the nature of the change, not the
implementation steps. Developers will figure out the how — they need to understand the what.

**Database/Migration** — If a migration is needed, note whether it's additive (safe to
deploy independently) or breaking (requires coordinated deployment). Flag any data
migration concerns.

**API Contract** — If endpoints change, note whether it's a new endpoint, a modified
contract (breaking vs. non-breaking), or a deprecated endpoint.

**Testing Strategy** — Be specific about what to test, not just "add unit tests."
Example: "Unit test the new validation logic. Integration test the full feature flow
against the configured test environment."

**Risk** — Low means straightforward, well-understood change. Medium means some complexity
or uncertainty. High means significant risk of regressions, data issues, or cross-system
impact. Always explain the rating.

**Cross-Repo Considerations** — Focus on deployment and coordination. Which repo should be
deployed first? Are there shared models or contracts that need to be aligned? Is a feature
flag needed so repos can be deployed independently?
