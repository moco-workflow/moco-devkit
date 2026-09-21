---
name: moco-developing-workflows
description: "Writes and edits Moco workflow YAML (wfspec) — statements, expressions, data flow, state machines, rules engines, child workflows. Use when: (1) creating a new .wfspec.yaml from requirements or an agreed plan, (2) editing or extending an existing wfspec, (3) answering questions about wfspec syntax, statement types, or expression rules, (4) wiring data between steps, or (5) converting a described pipeline into YAML. If feasibility is not yet settled, run moco-planning-workflows first."
---

# Developing Moco workflows

Turn an agreed design into valid wfspec YAML, then get it validated.

**Before writing anything:** if it is not already clear that Moco can do this and which activities
it needs, stop and use **`moco-planning-workflows`** — building around an activity type that does
not exist is the most expensive mistake available here. If the **moco-knowledge** plugin is
installed, use **`moco-consulting-kb`** to pull the authoring rules and the nearest existing
example before you start.

**Never start from a blank canvas.** Copy the closest spec in `moco-examples/` and adapt it.

---

## The loop

1. **Design** — statements and data flow (from the plan, if there is one).
2. **Write** — save to a `.wfspec.yaml` file.
3. **Validate** — `moco validate <file>`; fix and re-run until it passes. Non-negotiable.
4. **Run** — `moco run <file>` to confirm it behaves.
5. **Test** — see `moco-testing-workflows`.

For the full fix loop with error classification, use **`moco-validating-workflows`**.

## Skeleton

```yaml
# yaml-language-server: $schema=./workflowspec_schema.json

wfspec_name: descriptive-name    # required, kebab-case
wfspec_version: 1.0.0            # required, semver — start new specs at 1.0.0
context:                         # optional: constants and optional-with-default values
  retry_limit: 3
input_data:                      # optional: expected inputs; required ones are null
  order_id: null
  region: US
output_name: result              # optional: name the whole output (or use output_data)
body:                            # required
  sequence:
    elements:
      - transform:
          name: build-greeting
          output_data:
            - greeting#: "Hello {{name}}"
```

The schema modeline must be **line 1** — it drives IDE validation and autocomplete.

## Statements

There are exactly **13**. Anything else is not a statement.

**Primitives:** `transform`, `activity`, `workflow`, `call`, `abort`, `wait_for`, `emit_event`,
`continue_as_new_checkpoint`
**Composites:** `sequence`, `parallel`, `iteration`, `state_machine`, `rules_engine`

Pick with this:

| Need | Use |
|---|---|
| Compute, reshape, extract | `transform` |
| Call anything external | `activity` |
| Reuse other logic | `workflow` (child spec) |
| Reuse logic local to this spec | `call` + a top-level `functions:` entry |
| Validate / stop early / skip an item | `abort` |
| Steps in order | `sequence` |
| Independent work at once | `parallel` + `join_type` |
| Process a collection | `iteration` (+ `iter_type`, `join_type`) |
| Long-lived, event-driven, resumable | `state_machine` |
| Declarative fact inference | `rules_engine` |
| Pause for an external event | `wait_for` |
| Message another workflow | `emit_event` |
| Bound history on an endless loop | `continue_as_new_checkpoint` |

Full syntax for every statement, with the fields each one takes:
**[references/statement-reference.md](references/statement-reference.md)**

## Expressions

Every Python expression is wrapped in `{{ }}`. This is the rule people break most.

```yaml
- total#: "{{sum(amounts)}}"                     # expression
- message#: "Hello {{name}}, you have {{n}} items"   # template string
- status#: pending                               # literal — no braces
- tmpl#literal: "{{not evaluated}}"              # #literal suppresses evaluation
```

Variable-name modifiers — `name[@][#modifier][#]`:

| Modifier | Effect |
|---|---|
| `#` (trailing) | Log the evaluated value to the CLI. The main debugging tool. |
| `@` | Container scope — local to the enclosing composite |
| `#literal` | Do not evaluate |
| `#jinja` | Render as a Jinja2 template |
| `#python` | Force Python evaluation |
| `#python_glom` | Evaluate as a glom path |

Deeper: **[references/expression-guide.md](references/expression-guide.md)**

## Patterns

Common shapes — sequential pipeline, fan-out/fan-in, conditional branch, retry with backoff,
durable state, long-lived entity, event request/response — each pointing at a real spec to copy:
**[references/patterns.md](references/patterns.md)**

## Non-negotiables

1. **`moco validate` must pass** before you offer to run anything.
2. **Every expression is inside `{{ }}`.**
3. **`iter_item['field']`** — not `iter_item['value']['field']`.
4. **`timeout_sec` is a number literal**, never a string expression.
5. **`abort.type` is a literal** (`abort`, `terminate`, `raise`, `break`, `break_iteration`);
   gate the abort with `condition:`, never with an expression in `type:`.
6. **`parallel` requires `join_type`** — the schema rejects it otherwise. Set it on parallel
   iterations too.
7. **Schema modeline on line 1.**
8. **Name every step** — unnamed steps cannot be unit-tested.
9. **Never inline a secret** — use `builtin.secret.get`.
10. **Confirm every activity type exists** before using it
    (`moco-planning-workflows/scripts/list-activities.sh --exists <type>`).

## House style

- Prefix scratch variables with `_` to keep the context clean.
- Prefer a YAML comment over a `description:` field — `description` costs runtime overhead.
- kebab-case for step names.
- Quote only when YAML requires it, and use single quotes at the outermost level.
- Comment freely; the comments are read by both humans and models.
- Use `builtin.state.*` for anything that must outlive a step.
- `continue_as_new` for unbounded loops, so history stays bounded.
