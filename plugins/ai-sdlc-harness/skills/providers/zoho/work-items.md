# Zoho Work Item Adapter

Provider adapter for Zoho Mail Group Tasks. Used when `provider-config.md` specifies
`Work Item Provider: zoho`.

**Note:** Work items are tracked as **Group Tasks** in ZohoMail. Each group has a fixed
`groupId` (integer) that must be recorded in `provider-config.md` during init-workspace.
The `groupId` is required for every API call — there is no "list groups" tool, so it must
be obtained from the user or discovered via `ZohoMail_getMailAccounts`.

## MCP Server

- **Package**: `zoho` MCP server (user-level configuration)
- **Configuration**: Zoho OAuth credentials configured at the user level.
- **Tool prefix**: `mcp__zoho__ZohoMail_*` (Group Task subset only)

## Tool Reference

### Verify Connectivity

```
Tool: mcp__zoho__ZohoMail_getMailAccounts
Parameters: (none)
```

Use this during `init-workspace` to confirm the MCP server is reachable before asking
the user for their `groupId`.

---

### List Tasks (Work Items)

```
Tool: mcp__zoho__ZohoMail_listGroupTask
Parameters:
  path_variables:
    groupId: <integer>                # From provider-config.md
  query_params:                       # (optional)
    from: <integer>                   # Pagination offset
    limit: <integer>                  # Number of tasks to return
```

---

### Fetch a Single Task (Work Item)

```
Tool: mcp__zoho__ZohoMail_getGroupTask
Parameters:
  path_variables:
    groupId: <integer>
    taskId: <string>                  # Task ID (numeric string)
```

**Response mapping:**
- Title → `title`
- Description/Story body → `description`
- Acceptance Criteria → Embedded in `description` (parse `## Acceptance Criteria` section)
- Status → `status` (`"inprogress"` | `"completed"`)
- Priority → `priority` (`"high"` | `"medium"` | `"low"`)
- Assignee → `assignee` (Zoho user ID / Zuid)
- Due date → `dueDate` (dd/MM/yyyy)
- Category → `categoryId` (maps to label/type — resolve via `getCategoriesInGroupTasks`)

---

### Get Subtasks

```
Tool: mcp__zoho__ZohoMail_getSubtasksForGroupTask
Parameters:
  path_variables:
    groupId: <integer>
    taskId: <string>
```

Use to retrieve sub-items linked to a parent task.

---

### Create a Task (Work Item)

```
Tool: mcp__zoho__ZohoMail_addGroupTask
Parameters:
  path_variables:
    groupId: <integer>
  body:
    title: <string>                   # Required — task/story title
    description: <string>             # Story body + Acceptance Criteria
    priority: "high" | "medium" | "low"
    status: "inprogress" | "completed"
    assignee: <integer>               # Zuid of assignee (optional)
    dueDate: <string>                 # dd/MM/yyyy (optional)
    categoryId: <string>              # Category ID (optional)
    subtasks:                         # (optional) inline sub-task
      title: <string>
      description: <string>
      priority: "high" | "medium" | "low"
      status: "inprogress" | "completed"
      assignee: <integer>
      dueDate: <string>
      parentTaskId: <string>
```

---

### Update a Task (Work Item)

```
Tool: mcp__zoho__ZohoMail_editGroupTask
Parameters:
  path_variables:
    groupId: <integer>
    taskId: <string>
  body:
    title: <string>                   # (optional)
    description: <string>             # (optional)
    priority: "high" | "medium" | "low"  # (optional)
    status: "inprogress" | "completed"   # (optional)
    assignee: <integer>               # (optional)
    dueDate: <string>                 # (optional)
    categoryId: <string>              # (optional)
```

---

### Delete a Task

```
Tool: mcp__zoho__ZohoMail_deleteGroupTask
Parameters:
  path_variables:
    groupId: <integer>
    taskId: <string>
  query_params:
    forceDelete: <boolean>            # true = permanent delete
```

---

### List Categories (Labels / Types)

```
Tool: mcp__zoho__ZohoMail_getCategoriesInGroupTasks
Parameters:
  path_variables:
    groupId: <integer>
  query_params:
    defaultCategory: <boolean>        # true = include default category in response
```

Use during init-workspace to enumerate available categories (story, bug, task, etc.)
and record their IDs in `provider-config.md`.

---

### Create a Category

```
Tool: mcp__zoho__ZohoMail_addCategoriesInGroupTasks
Parameters:
  path_variables:
    groupId: <integer>
  body:
    categoryName: <string>
```

## ID Format

- **Type**: String (large numeric ID)
- **Format**: `"1775133062323162000"` (numeric string — do NOT cast to integer, precision loss)
- **Display format**: `#<taskId>` (shortened) or full ID in API calls
- **In commit messages**: `#<TASK-ID> #T1: description` (both IDs mandatory)
- **groupId**: Integer — always required alongside `taskId`. Record in `provider-config.md`.

## Work Item Hierarchy

```
Group (groupId)
  └── Task (work item / user story)
        └── Subtask (implementation detail)
```

**Recommended mapping for SDLC workflow:**
- **User Story** → Group Task (`title` + `description` with embedded AC)
- **Sub-task / implementation task** → Subtask (via `subtasks` field or `parentTaskId`)
- **Type/Label** → Category (`categoryId`)
- **Sprint/Milestone** → `dueDate` + category convention (no native sprint concept)

## Status Model

Zoho Group Tasks has a **binary status**: `inprogress` or `completed`.

There is no native multi-step status (e.g., In Review, Blocked). Teams work around this
using **categories** to represent richer states, or by convention in the description.

> **Recommendation:** Use categories for story type (Feature, Bug, Chore) and rely on the
> task tracker in the workflow for internal status tracking (Pending / In Progress / In Review
> / Done). Only sync terminal states back to Zoho (`completed` when Done).

## Provider-Specific Quirks

1. **No "list groups" API**: The `groupId` cannot be discovered programmatically. It must
   be provided by the user during `init-workspace` (visible in the Zoho Mail URL or group
   settings). Verify it works by calling `listGroupTask`.

2. **Binary status**: Only `inprogress` and `completed` are valid status values. Do not
   attempt to set any other value — the API will reject it.

3. **Large numeric task IDs**: Task IDs are very large integers (e.g., `1775133062323162000`).
   Always treat them as strings to avoid floating-point precision loss in JavaScript/JSON.

4. **No search API**: There is no search or filter endpoint — `listGroupTask` returns all
   tasks (paginated). Filter in-memory after fetching if needed.

5. **No comment API for group tasks**: Unlike Jira or GitHub, there is no dedicated
   "add comment to task" tool. Use `editGroupTask` to append notes to the `description`
   field if discussion tracking is needed.

6. **Assignee is a Zuid (integer)**: Zoho user IDs are integers, not usernames. During
   init-workspace, ask the user for the relevant Zuids or look them up via `getMailAccounts`.

7. **AC must be embedded in description**: There is no dedicated Acceptance Criteria field.
   Embed ACs in the `description` under a `## Acceptance Criteria` section. The planner
   must parse this section when ingesting a story.

## Planner Tool List (for agent frontmatter)

```
mcp__zoho__ZohoMail_listGroupTask, mcp__zoho__ZohoMail_getGroupTask, mcp__zoho__ZohoMail_getSubtasksForGroupTask, mcp__zoho__ZohoMail_getCategoriesInGroupTasks, mcp__zoho__ZohoMail_editGroupTask
```

## Disallowed Tool Pattern (for non-planner agents)

```
mcp__zoho__ZohoMail_*
```

## Field Mapping Summary

> Concept definitions: `skills/providers/shared/work-item-concepts.md`

| Generic Concept | Zoho Field | Notes |
|----------------|------------|-------|
| Title | `title` | |
| Description | `description` | Plain text; embed AC here |
| Acceptance Criteria | Embedded in `description` | Parse `## Acceptance Criteria` section |
| State | `status` | `"inprogress"` or `"completed"` only |
| Type / Label | `categoryId` | Resolve names via `getCategoriesInGroupTasks` |
| Priority | `priority` | `"high"` / `"medium"` / `"low"` |
| Assignee | `assignee` | Zuid (integer) |
| Due Date / Sprint | `dueDate` | dd/MM/yyyy; no native sprint concept |
| Subtasks | `subtasks` / `getSubtasksForGroupTask` | Inline on create or via separate fetch |
| Group / Project | `groupId` | Integer; constant per team — store in provider-config.md |
