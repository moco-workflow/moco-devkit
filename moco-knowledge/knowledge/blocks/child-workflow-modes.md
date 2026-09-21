---
id: child-workflow-modes
what: Calling another wfspec, by registry name or inline, in one of four execution modes.
use_when: Reusing logic, isolating something testable, or launching work that outlives the caller.
inputs:
  - {name: wfspec, type: dict}
  - {name: child_mode, type: str}
  - {name: input_data, type: dict}
outputs:
  - {name: child_result, type: any}
follows: [child-workflow-as-data-resolver, named-steps-are-testable]
pairs_with: [functions-and-call, entity-workflow, parallel-fan-out]
from: workflow
seen_in: [moco-workflow-demo, contract-intelligence-agent]
status: active
---

# Child workflow modes

Two independent axes: **how the spec is referenced** (registry `name`+`version`, or inline
`content`) and **how it runs** (`child_mode`).

| `child_mode` | Context | Parent waits? | Outlives parent? |
|---|---|---|---|
| `inline` | Shared with parent | yes | no |
| `sync` | Its own | yes | no |
| `async` | Its own | no | no |
| `detached` | Its own | no | yes |

## Snippet

```yaml
- workflow:
    name: score-order
    wfspec:
      name: order-scorer
      version: "1.0.0"
    child_mode: sync
    input_data:
      order: "{{order}}"
    output_name: scored
```

Fan out work you do not wait for:

```yaml
- workflow:
    name: launch-analyzer
    wfspec: {name: clause-analyzer}
    child_mode: async
    input_data: {doc: "{{doc}}"}
```

## Watch out

- **`inline` shares the parent's context** — the child can read and clobber the parent's
  variables. Convenient, and the reason an `inline` child is not independently testable. Prefer
  `sync` when you want isolation.
- **`async` and `detached` return no result to the parent.** If you need the answer, either use
  `sync`, or have the child report back with `emit_event` and `wait_for` on a correlation id.
- A `terminate` inside a child does **not** stop the parent. Aborts that must kill the whole run
  belong in the parent.
- Pin `version` for a registry child. Unpinned, the child can change under you.
- For small logic used only by this spec, a `functions-and-call` function is lighter than a whole
  child wfspec — no separate file, no registry entry, and a fresh context by construction.
