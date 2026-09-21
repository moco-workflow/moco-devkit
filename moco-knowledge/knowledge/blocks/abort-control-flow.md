---
id: abort-control-flow
what: Stopping a workflow, failing it, or skipping part of it — the five abort types.
use_when: Validating input, refusing to proceed on a business condition, exiting a block early, or skipping a bad item mid-loop.
inputs:
  - {name: condition, type: bool}
  - {name: message, type: str}
  - {name: type, type: str}
outputs: []
follows: [abort-type-is-literal, named-steps-are-testable, test-the-boundary]
pairs_with: [namespace-state-store, parallel-fan-out, external-system-lifecycle]
from: abort
seen_in: [moco-workflow-demo, task-manager, trade-simulator, k8s-demo, moco-agent]
status: active
---

# Abort control flow

The abort fires when `condition` is **True** — so invert the guard you are thinking of.

| `type` | Raises? | Effect |
|---|---|---|
| `abort` | yes | Stop with an error |
| `terminate` | no | Stop gracefully — a business condition was not met |
| `raise` | yes | Raise the custom `error` object |
| `break` | no | Leave the enclosing block; the workflow continues |
| `break_iteration` | no | Skip this item; the loop continues |

## Snippet

```yaml
- abort:
    name: require-order-id
    type: raise
    condition: "{{order_id is None}}"
    message: "order_id is required"
    error:
      code: VALIDATION_ERROR

- abort:
    name: nothing-to-do
    type: terminate            # not an error — a normal outcome
    condition: "{{not orders}}"
    message: "No orders for {{region}}"

- abort:
    name: skip-malformed
    type: break_iteration
    condition: "{{iter_item.get('id') is None}}"
    message: "skipping row with no id"
```

## Watch out

- **`type` is a literal** (rule `abort-type-is-literal`). It cannot be an expression — branch by
  writing two aborts with different conditions.
- **`terminate` vs `raise` is a real decision.** `terminate` means "correctly did nothing";
  `raise` means "something is broken". Getting it wrong turns a quiet no-op into a page, or hides
  a genuine failure as a clean exit.
- `message` is required, and it is what a test asserts on — make it specific and include the
  values that explain the decision.
- Order matters: put cheap guards before expensive fetches.
- Guard each field at the point it is first used, rather than front-loading one combined
  "is the data usable" check. A combined guard turns a case the workflow would have skipped
  cleanly into a hard failure.
- Name every abort (rule `named-steps-are-testable`) and unit-test it — one case per guard,
  asserting the specific `terminate`/`error`, including the boundary.
