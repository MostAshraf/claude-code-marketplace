# Local Markdown Work Item Adapter

Provider adapter for user stories stored as local `.md` files. Used when
`provider-config.md` specifies `Work Item Provider: local-markdown`.

No MCP server or external system required. The story is read directly from
the filesystem using the `Read` tool, and refined versions are written back
using the `Write` tool.

## MCP Server

- **Package**: none — file system only
- **Configuration**: none required

## Work Item ID

For `local-markdown`, the **work item ID is the file path** passed as the
second argument to a story-workflow command:

```
/story-workflow improve ./stories/auth-story.md
/story-workflow analyze /home/dev/stories/PROJ-123.md
/story-workflow refine stories/subscription-flow.md
```

The path may be absolute or relative to the current working directory.
The filename (without extension) is used wherever a short ID is needed
(e.g., commit messages).

## Tool Reference

### Fetch a Story

```
Tool: Read
Parameters:
  - file_path: <the work item ID — the file path>
```

Read the file at the given path. If the file does not exist, inform the user
and stop — do not attempt to create it.

**Parsing the content:**

The adapter recognises these optional markdown sections by their H2 headings:

| Section heading | Maps to |
|-----------------|---------|
| (first H1) | Title |
| (prose before first H2) | Description |
| `## Acceptance Criteria` | Acceptance Criteria |
| `## Out of Scope` | Out of Scope |
| `## Open Questions` | Open Questions |
| `## Technical Notes` | Technical Notes |
| Any other H2 section | Included as-is in the story body |

**Unstructured files** (no headings at all) are fully supported — treat the
entire file content as the description, and leave Title blank (ask the user
for it in the gap-filling step).

**Partial structure** is fine too — only extract the sections that are present;
treat missing sections as empty.

### Post Back / Save Refined Story

There is no remote system to post a comment to. Instead, after the user
approves the final version, ask:

> "Save the improved story back to `<file path>`? This will overwrite the
> current file."

If confirmed, use the `Write` tool to overwrite the file with the refined
content in the standard story template format.

If the user declines, the refined story has already been presented in the
conversation — they can copy it manually.

```
Tool: Write
Parameters:
  - file_path: <the same file path used to fetch the story>
  - content: <the approved refined story in markdown>
```

**Never overwrite without explicit user confirmation.**

### Operations Not Applicable

The following operations from other providers have no equivalent for local
files. Skip them gracefully — do not error, do not ask the user for credentials:

| Operation | Behaviour for local-markdown |
|-----------|------------------------------|
| List comments / revisions | Skip — no comment history |
| Fetch batch / search items | Skip — not applicable |
| Search code via work item | Use Grep/Glob on local repos directly |
| Get item type/schema | Skip — no type system |

## Recommended File Format

Stories can be unstructured plain prose, but the following format gives the
best results with all story-workflow commands:

```markdown
# Story Title

Brief context — the "why" behind this story (2-4 sentences).

## Acceptance Criteria
- Given <precondition>, When <action>, Then <outcome>
- Given <precondition>, When <action>, Then <outcome>

## Out of Scope
- List explicit exclusions here

## Open Questions
- [PO] Question for the product owner
- [Tech] Technical question to resolve

## Technical Notes
- Leave empty; populated by /story-workflow groom
```

## ID Format

- **Type**: File path string (absolute or relative)
- **Display**: Filename only (e.g., `auth-story.md`)
- **Short ID for commit messages**: Filename without extension (e.g., `auth-story`)
- **In commit messages**: `auth-story #T1: description` (filename-without-ext + task ref)

## Field Mapping Summary

> Concept definitions: `skills/providers/shared/work-item-concepts.md`

| Generic Concept | Markdown Element | Notes |
|----------------|-----------------|-------|
| Title | First H1 heading (`# ...`) | Entire line after `# ` |
| Description | Prose before the first H2 | May be multi-paragraph |
| Acceptance Criteria | `## Acceptance Criteria` section | List items or prose |
| Out of Scope | `## Out of Scope` section | |
| Open Questions | `## Open Questions` section | |
| Technical Notes | `## Technical Notes` section | |
| State | N/A | Treated as always "open" |
| Area / Project | N/A | Use repos-metadata.md for domain context |
| Sprint / Iteration | N/A | |
| Story Points | N/A | |
| Linked Items | N/A | |

## Provider-Specific Quirks

1. **File path as ID**: The "ID" is not a number or key — it's a path. Validation
   should check that the file exists and is readable, not that it matches a numeric
   or key format.

2. **No comment thread**: Refinements are saved in-place (overwrite) or left in
   the conversation. There is no persistent comment history.

3. **Already markdown**: No format conversion needed. The file is read and written
   as-is in GitHub Flavored Markdown.

4. **Relative paths**: Resolve relative paths against the current working directory
   (the harness root, typically). If a path is ambiguous, show the resolved absolute
   path before reading.

5. **`/story-workflow groom`**: The groom command scans local repos for technical
   context. With `local-markdown`, this works exactly as with other providers —
   `repos-metadata.md` and `repos-paths.md` are used for the codebase scan.

## Planner Tool List (for agent frontmatter)

```
(none — local-markdown requires no MCP tools)
```

## Disallowed Tool Pattern (for non-planner agents)

```
(none — no provider MCP namespace to block)
```
