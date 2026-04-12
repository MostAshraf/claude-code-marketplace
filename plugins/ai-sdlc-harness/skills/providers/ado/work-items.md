# ADO Work Item Adapter

Provider adapter for Azure DevOps Work Items. Used when `provider-config.md` specifies
`Work Item Provider: ado`.

## MCP Server

- **Package**: `@anthropic/azure-devops-mcp`
- **Configuration**: Requires ADO organization URL and PAT token in MCP server config.

## Tool Reference

### Fetch a Work Item

```
Tool: mcp__azure-devops__wit_get_work_item
Parameters:
  - id: <integer>                    # The work item ID
  - project: <string>               # ADO project name (from provider-config.md)
  - expand: "relations"             # Always include to get linked items
```

**Response mapping:**
- Title → `fields["System.Title"]`
- Description → `fields["System.Description"]` (HTML format — normalize to markdown)
- Acceptance Criteria → `fields["Microsoft.VSTS.Common.AcceptanceCriteria"]` (HTML)
- State → `fields["System.State"]`
- Area Path → `fields["System.AreaPath"]`
- Iteration Path → `fields["System.IterationPath"]`
- Story Points → `fields["Microsoft.VSTS.Scheduling.StoryPoints"]`
- Linked Items → `relations[]` array (filter by `rel` type)
- Attachments → `relations[]` where `rel == "AttachedFile"`

### Fetch Multiple Work Items

```
Tool: mcp__azure-devops__wit_get_work_items_batch_by_ids
Parameters:
  - ids: [<integer>, ...]            # Array of work item IDs
  - project: <string>
```

### List Comments

```
Tool: mcp__azure-devops__wit_list_work_item_comments
Parameters:
  - workItemId: <integer>
  - project: <string>
```

### List Revisions (Change History)

```
Tool: mcp__azure-devops__wit_list_work_item_revisions
Parameters:
  - workItemId: <integer>
  - project: <string>
```

### Get Work Item Type Schema

```
Tool: mcp__azure-devops__wit_get_work_item_type
Parameters:
  - typeName: <string>               # e.g., "User Story", "Task", "Bug"
  - project: <string>
```

### Add Comment

```
Tool: mcp__azure-devops__wit_add_work_item_comment
Parameters:
  - workItemId: <integer>
  - project: <string>
  - text: <string>                   # HTML-formatted comment body
```

**Note:** ADO comments support HTML. Convert markdown to HTML before posting.

### Search Work Items

```
Tool: mcp__azure-devops__search_workitem
Parameters:
  - searchText: <string>
  - project: <string>
```

### Search Code

```
Tool: mcp__azure-devops__search_code
Parameters:
  - searchText: <string>
  - project: <string>
```

## ID Format

- **Type**: Integer
- **Display format**: `#12345`
- **In commit messages**: `#<STORY-ID> #<TASK-ID>` (e.g., `#123456 #T1`)

## Work Item Hierarchy

Typical ADO hierarchy: `Epic > Feature > User Story > Task`
Configurable in `provider-config.md`.

## Provider-Specific Quirks

1. **HTML fields**: Description and Acceptance Criteria are stored as HTML. Always normalize
   to markdown when presenting to agents, and convert back to HTML when posting comments.
2. **Relations**: Linked items use relation types like `System.LinkTypes.Hierarchy-Forward`
   (child), `System.LinkTypes.Hierarchy-Reverse` (parent), `System.LinkTypes.Related`.
3. **Area Path**: Used for team routing. Format: `Project\Area\SubArea`.
4. **Custom fields**: Teams may have custom fields. These are documented in `provider-config.md`
   during init-workspace.

## Field Mapping Summary

> Concept definitions: `skills/providers/shared/work-item-concepts.md`

| Generic Concept | ADO Field | Notes |
|----------------|-----------|-------|
| Title | `fields["System.Title"]` | |
| Description | `fields["System.Description"]` | HTML — normalize to markdown when reading |
| Acceptance Criteria | `fields["Microsoft.VSTS.Common.AcceptanceCriteria"]` | HTML — normalize to markdown |
| State | `fields["System.State"]` | |
| Area/Project | `fields["System.AreaPath"]` | Format: `Project\Area\SubArea` |
| Sprint | `fields["System.IterationPath"]` | |
| Story Points | `fields["Microsoft.VSTS.Scheduling.StoryPoints"]` | |
| Linked Items | `relations[]` | Filter by `rel` type (Hierarchy-Forward, Hierarchy-Reverse, Related) |

## Planner Tool List (for agent frontmatter)

```
mcp__azure-devops__wit_get_work_item, mcp__azure-devops__wit_get_work_items_batch_by_ids, mcp__azure-devops__wit_list_work_item_comments, mcp__azure-devops__wit_list_work_item_revisions, mcp__azure-devops__wit_get_work_item_type, mcp__azure-devops__search_workitem, mcp__azure-devops__search_code
```

## Disallowed Tool Pattern (for non-planner agents)

```
mcp__azure-devops__*
```
