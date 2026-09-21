---
id: parallel-fan-out
what: Running independent work concurrently — a fixed set of branches, or one branch per item in a collection.
use_when: Several operations do not depend on each other and latency matters.
inputs:
  - {name: join_type, type: str}
  - {name: input_data, type: list}
outputs:
  - {name: results, type: list}
follows: [parallel-requires-join-type, iter-item-direct-field-access, named-steps-are-testable]
pairs_with: [ai-agent-activity, external-system-lifecycle, abort-control-flow]
from: "parallel / iteration"
seen_in: [moco-workflow-demo, ai-agent-demo, sre-incident-agent, contract-intelligence-agent, moco-agent]
status: active
---

# Parallel fan-out

Two forms. `parallel` for a **fixed set of named branches**; `iteration` with
`iter_type: parallel` for **one branch per item**.

## Snippet

```yaml
parallel:
  join_type: and            # and = wait for all; or = first to finish wins
  elements:
    - activity: {type: http.request, name: fetch-prices, input_data: {...}}
    - activity: {type: http.request, name: fetch-news, input_data: {...}}
  output_name: both
```

```yaml
iteration:
  iter_type: parallel
  join_type: and            # required here too
  input_data: "{{tickers}}"
  body:
    activity:
      type: http.request
      name: fetch-one
      input_data: {url: "{{api}}/{{iter_item}}"}
  output_name: quotes
```

## Watch out

- **`join_type` is required by the schema on `parallel`** (rule `parallel-requires-join-type`),
  and a parallel iteration needs it too. Omitting it fails validation, not silently at runtime.
- `join_type: or` returns as soon as one branch finishes — the others may still be in flight. Do
  not use it for work with side effects unless that is genuinely what you want.
- `iter_item` **is** the item (rule `iter-item-direct-field-access`) — `iter_item['field']`,
  never `iter_item['value']['field']`.
- `iteration.input_data` must evaluate to a list. An empty list is a no-op, not an error — if
  empty means something is wrong, guard it with an `abort`.
- Parallel branches do not see each other's outputs. Anything shared must exist before the block.
- Fanning out over a large collection multiplies load on whatever each branch calls. Bound it.
