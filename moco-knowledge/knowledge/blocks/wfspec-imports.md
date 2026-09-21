---
id: wfspec-imports
what: Sharing constants across specs by importing context from a body-less config spec.
use_when: Two or more specs need the same constants and duplicating them would let them drift.
inputs: []
outputs: []
follows: [comment-freely]
pairs_with: [child-workflow-modes]
from: wfspec_imports
seen_in: [moco-workflow-demo]
status: active
---

# wfspec imports

A config spec has `context` and no `body`. Other specs import it and read its values as their own.

## Snippet

```yaml
# shared-config-demo.yaml — no body; this spec exists only to carry context
wfspec_name: shared-config-demo
wfspec_version: 1.0.0
context:
  api_base: https://api.example.com
  retry_limit: 3
```

```yaml
# the consumer
wfspec_imports:
  - name: shared-config-demo
    version: "1.0.0"

body:
  activity:
    type: http.request
    name: fetch
    input_data:
      url: "{{api_base}}/orders"
```

## Watch out

- Imported values land in the **same namespace** as local context, so a local key of the same
  name shadows the import. Prefix shared keys if that is a risk.
- Pin the `version`. An unpinned import can change the importing spec's behaviour without the
  spec changing.
- For constants, not logic. Anything with a `body` is a child workflow (`child-workflow-modes`)
  or a function (`functions-and-call`).
- Values that differ per environment belong in secrets or inputs, not here.
