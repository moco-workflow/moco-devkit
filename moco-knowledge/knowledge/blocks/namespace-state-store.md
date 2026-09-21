---
id: namespace-state-store
what: Durable key/value state grouped into namespaces, surviving steps, runs and workflows.
use_when: Anything must be remembered past the step that computed it — status, cursors, accumulated results, cross-workflow handoff.
inputs:
  - {name: namespace, type: str}
  - {name: key, type: str}
  - {name: value, type: any}
outputs:
  - {name: value, type: any}
follows: [durable-state-via-builtin-state, named-steps-are-testable]
pairs_with: [abort-control-flow, entity-workflow, cross-workflow-events]
from: builtin.state.*
seen_in: [task-manager, moco-agent, tech-signal-feed, trade-simulator]
status: active
---

# Namespace state store

The most-used activity family in the corpus by a wide margin. Eight activities:
`set_state`, `get_state`, `get_state_with_ts`, `del_state`, `list_states`, `list_namespaces`,
`update_topic`, `delete_by_topic`.

## Snippet

```yaml
- activity:
    type: builtin.state.set_state
    name: mark-submitted
    input_data:
      namespace: submitted
      key: "{{task_id}}"
      value: "{{task}}"

- activity:
    type: builtin.state.list_states
    name: list-pending
    input_data:
      namespace: submitted
    output_name: pending
```

**Status as namespace membership** — the pattern `task-manager` is built on. A task's status is
*which namespace it lives in*, so a transition is a write to the new namespace plus a delete from
the old. Listing a status is then one `list_states` rather than a scan-and-filter.

## Watch out

- A namespace is a flat keyspace. Model hierarchy in the key, not by inventing namespaces per
  entity, or `list_namespaces` becomes useless.
- `list_states` returns everything in the namespace. On a large namespace that is the expensive
  call in the workflow — reach for `get_state` when you know the key.
- Moving between namespaces is **not atomic**. Write the new one first, then delete the old, so a
  crash duplicates rather than loses.
- Use `get_state_with_ts` when staleness matters; plain `get_state` gives you no way to tell a
  fresh value from an old one.
- Do not use this as a scratchpad. Values that live only until the next step belong in a
  `_`-prefixed transform output (rule `underscore-prefix-for-scratch`).
