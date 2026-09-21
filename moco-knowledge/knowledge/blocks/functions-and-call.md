---
id: functions-and-call
what: A reusable function declared inside a wfspec and invoked with the call statement.
use_when: The same logic is needed more than once inside one spec, and it does not deserve its own file.
inputs:
  - {name: function, type: str}
  - {name: input_data, type: dict}
outputs:
  - {name: output_data dict, type: dict}
follows: [child-workflow-as-data-resolver, named-steps-are-testable]
pairs_with: [child-workflow-modes]
from: "functions + call"
seen_in: [moco-workflow-demo, tech-signal-feed, trade-simulator]
status: active
---

# Functions and `call`

A function is a subset of a wfspec — `input_data`, `output_data`, `body` — declared at the top
level and run as an inline child workflow. `call` invokes it.

## Snippet

```yaml
functions:
  - function: add
    input_data:
      a:
      b:
    output_data:
      sum: "{{ a + b }}"
    body:
      transform: {}

  - function: add_then_square       # functions may call siblings
    input_data:
      a:
      b:
    output_data:
      value: "{{ squared }}"
    body:
      sequence:
        elements:
          - call:
              function: add
              input_data: {a: "{{a}}", b: "{{b}}"}
              output_name: sum
          - transform:
              output_data:
                - squared: "{{ sum * sum }}"

body:
  call:
    function: add_then_square
    name: compute
    input_data: {a: "{{x}}", b: "{{y}}"}
    output_name: result
```

## Watch out

- **`output_name` binds the function's whole `output_data` dict, not a scalar.** With
  `output_data: {sum: ...}` and `output_name: total`, `total` is `{'sum': 120}` — so
  `total > threshold` fails with
  `'>' not supported between instances of 'dict' and 'int'`. Either read the field
  (`total['sum']`) or destructure at the call site with `output_data` instead of `output_name`.
  Verified 2026-09-15; the error names the comparison, not the call, so it is easy to misread as
  a problem in the comparing transform.
- **Each call runs in a fresh context.** A function cannot read or clobber the caller's
  variables — only what you pass in is visible. That isolation is the main reason to prefer a
  function over an `inline` child workflow.
- `function:` is the only required field on `call`, and it must name an entry in the top-level
  `functions:` list.
- Declare parameters as empty keys under the function's `input_data` (`a:` with no value).
- Functions are local to the spec. If two specs need the same logic, it is a child wfspec
  instead (see `child-workflow-modes`).
- Easy to miss — it is not in the older skill docs. Read
  `moco-examples/moco-workflow-demo/src/functions-demo.yaml`, which documents the semantics in
  its own header comments.
