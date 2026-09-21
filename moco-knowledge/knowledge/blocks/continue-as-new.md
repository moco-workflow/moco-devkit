---
id: continue-as-new
what: Restarting a long-running workflow with fresh history so it does not grow without bound.
use_when: A workflow loops indefinitely, or is a long-lived state machine or entity workflow.
inputs:
  - {name: condition, type: bool}
  - {name: serialize_data_context, type: bool}
outputs: []
follows: [continue-as-new-for-unbounded-loops]
pairs_with: [state-machine-transitions, entity-workflow, namespace-state-store]
from: continue_as_new_checkpoint
seen_in: [moco-workflow-demo, moco-agent, tech-signal-feed, trade-simulator]
status: active
---

# Continue as new

The statement is **`continue_as_new_checkpoint`** — not `continue_as_new`.

## Snippet

```yaml
- continue_as_new_checkpoint:
    name: checkpoint
    condition: "{{not is_continue_as_new}}"   # fires when True
    serialize_data_context: true              # carry context into the new run
```

Typically placed at the end of a loop body, with a flag set on re-entry so the spec can tell a
fresh start from a continuation.

## Watch out

- Every event a workflow produces stays in its history. Without a checkpoint, a workflow that
  runs for days accumulates history until it fails — and it fails late, in production, not in
  any test.
- `serialize_data_context: true` carries the context forward. Without it the new run starts
  clean and anything not passed explicitly is gone.
- `enforce: true` forces the restart regardless of history size. It exists for tests — leave it
  off in real specs, where the runtime should decide.
- Anything that must survive the restart and is not in the serialized context belongs in
  `namespace-state-store`.
- The restart is invisible to callers: same workflow id, new run.
