---
id: debug-tracing
what: Seeing what a workflow actually computed — the trailing-# modifier and its siblings.
use_when: Any time a workflow does not do what you expected.
inputs: []
outputs: []
follows: [trailing-hash-for-debug, underscore-prefix-for-scratch, container-scope-modifier]
pairs_with: [namespace-state-store]
from: "variable name modifiers"
seen_in: [moco-workflow-demo, task-manager]
status: active
---

# Debug tracing

Append `#` to a variable name and its evaluated value streams to the CLI. This is the debugging
tool — there is no separate log statement.

## Snippet

```yaml
- transform:
    name: inspect
    output_data:
      - _sample#: "{{orders[:3]}}"          # scratch + logged
      - log#: "Processing {{len(orders)}} orders"
      - total@#: "{{sum(o['amt'] for o in orders)}}"   # container-scoped + logged
```

Full modifier set — `name[@][#modifier][#]`:

| Modifier | Effect |
|---|---|
| `#` trailing | Log the evaluated value |
| `@` | Container scope — local to the enclosing composite |
| `#literal` | Do not evaluate |
| `#jinja` | Render as a Jinja2 template |
| `#python` | Force Python evaluation |
| `#python_glom` | Evaluate as a glom path |

## Watch out

- **Running a local file, traces print automatically. Running a deployed workflow by name, you
  need `--debug`.** Expecting traces from a deployed run without it is a common few minutes lost.
- Child workflow traces are collected automatically — you do not need to plumb them up.
- `log#` is not a keyword. It is just a variable named `log` with the logging modifier; the name
  is arbitrary.
- Combine `_` and `#` for scratch values you only want to see once
  (rule `underscore-prefix-for-scratch`), so they do not linger in the context.
- Logged values land in CLI output and traces. Do not log a secret.
