# Statement reference

Every wfspec statement, the fields it takes, and a real spec in `moco-examples/` that uses it.

---

## Primitives

### `transform` — compute and reshape

```yaml
transform:
  name: score-orders            # name it, or it cannot be unit-tested
  condition: "{{has_orders}}"   # optional; skip the step when false
  input_data:
    - raw: "{{orders}}"
  output_data:
    - total#: "{{sum(o['amount'] for o in raw)}}"
    - _scratch: "{{raw[:10]}}"  # leading _ keeps it out of the shared context
```

No I/O — pure data. Every `output_data` entry is evaluated, so make values None-safe.

### `activity` — do something external

```yaml
activity:
  type: http.request            # required; must be a real activity type
  name: fetch-orders
  input_data:
    method: GET
    url: "{{api_url}}/orders"
  output_name: orders_raw       # whole output under this name
  output_data:                  # or pick fields out of it
    - status#: "{{_raw_output['status']}}"
  condition: "{{should_fetch}}"
  retry_policy:                 # timeouts and retries live HERE, not on the activity
    timeout_sec: 30             # number literal, never an expression
    max_attempts: 3
  enable_cache: true
  async_mode: false
```

**`timeout_sec` is not a property of `activity`.** The full `ActivityRecord` field set is `type`
(the only required one), `version`, `config_data`, `input_data`, `output_name`, `output_data`,
`name`, `description`, `condition`, `retry_policy`, `execute_locally`, `enable_cache`,
`cache_policy`, `async_mode`, `async_event_topic`. Putting `timeout_sec` or `max_retry_attempts`
directly on the activity fails validation — and because `body` is a union, it fails with the
misleading `/body` cascade rather than naming the field.

`retry_policy` takes: `timeout_sec`, `schedule_to_close_timeout_sec`, `heartbeat_timeout_sec`,
`heartbeat_interval_sec`, `max_attempts`, `initial_interval_sec`, `backoff_coefficient`,
`maximum_interval_sec`, `non_retryable_error_types`.

`wait_for` and `state_machine` **do** take a top-level `timeout_sec`. Activities do not.

183 activity types exist. Confirm one with
`moco-planning-workflows/scripts/list-activities.sh --exists <type>`, and read its inputs with
`--schema <type>`. Do not guess activity input fields.

### `workflow` — call a child workflow

```yaml
workflow:
  wfspec:
    name: order-processor       # registry lookup
    version: "1.0.0"
  # ...or define it inline:
  #   content#literal: |
  #     wfspec_name: inline-child
  #     wfspec_version: 1.0.0
  #     body: {transform: {output_data: [{r#: "ok"}]}}
  child_mode: sync              # inline | sync | async | detached
  input_data:
    order_id: "{{order_id}}"
  output_name: child_result
```

| `child_mode` | Behaviour |
|---|---|
| `inline` | Runs in the parent's context — shares variables |
| `sync` | Independent workflow; parent waits |
| `async` | Independent; parent does not wait |
| `detached` | Independent; outlives the parent |

All four side by side: `moco-examples/moco-workflow-demo/src/child-workflow-modes-demo.yaml`

### `abort` — stop, skip, or fail

```yaml
abort:
  name: reject-empty
  type: terminate               # literal, never an expression
  condition: "{{not orders}}"   # the abort fires when this is True
  message: "No orders for {{region}}"
  error:                        # only with type: raise
    code: VALIDATION_ERROR
```

| `type` | Raises? | Effect |
|---|---|---|
| `abort` | yes | Stop the workflow with an error |
| `terminate` | no | Stop gracefully — business condition not met |
| `raise` | yes | Raise the custom `error` object |
| `break` | no | Leave the enclosing block; workflow continues |
| `break_iteration` | no | Skip this item; the loop continues |

All five: `moco-examples/moco-workflow-demo/src/abort-demo.yaml`

### `wait_for` — pause until an event arrives

```yaml
wait_for:
  event:
    topic: order_events         # optional, defaults to 'default'
    event_type: order_shipped   # optional
    match_expression: "{{event.get('data', {}).get('id') == order_id}}"
  timeout_sec: 300              # number literal
  output_name: shipped_event
```

`moco-examples/moco-workflow-demo/src/events-demo.yaml`,
`moco-examples/client-server-demo/src/task-service-client.yaml`

### `emit_event` — message another workflow

```yaml
emit_event:
  input_data:
    topic: order_events
    event_type: order_placed
    target_workflow_id: "order-entity:{{order_id}}"
    data:
      order_id: "{{order_id}}"
```

**Start-or-signal** — guarantee the target entity workflow is running first:

```yaml
emit_event:
  entity_child_workflow:
    wfspec:
      name: order-entity
    input_data:
      order_id: "{{order_id}}"
    child_mode: async           # async (default) or detached
  input_data:
    topic: order_events
    event_type: place
    target_workflow_id: "order-entity:{{order_id}}"
    data: "{{payload}}"
```

`moco-examples/entity-workflow-demo/src/entity-workflow-demo.yaml`

---

## Composites

### `sequence`

```yaml
sequence:
  name: pipeline
  elements:
    - activity: {...}
    - transform: {...}
  output_name: pipeline_result
```

### `parallel`

```yaml
parallel:
  join_type: and                # REQUIRED by the schema. and = wait for all; or = first wins
  elements:
    - activity: {...}
    - activity: {...}
  output_name: results
```

`join_type` and `elements` are both required — omitting `join_type` fails validation.

`moco-examples/moco-workflow-demo/src/parallel-demo.yaml`

### `iteration`

```yaml
iteration:
  iter_type: parallel           # parallel | sequence
  join_type: and                # required when iter_type is parallel
  input_data: "{{orders}}"      # must evaluate to a list
  body:
    transform:
      name: score-one
      output_data:
        - score#: "{{iter_item['amount'] * 0.1}}"
  output_name: scores
```

`iter_item` **is** the item. Use `iter_item['field']`, never `iter_item['value']['field']`.
`iter_items` holds the nested structure; `iter_item` == `iter_items[-1]`.

`moco-examples/moco-workflow-demo/src/iteration-demo.yaml`

### `state_machine`

```yaml
state_machine:
  initial_state: pending
  event_source_topic: order_events
  states:
    - name: pending
      on_enter: {...}
      timeout_sec: 600
    - name: done
      is_terminal: true
  transitions:
    - from_state: pending       # event-driven
      to_state: done
      trigger:
        event_type: complete
        condition: "{{event.get('data', {}).get('ok')}}"
    - from_state: draft         # direct — fires as soon as on_enter finishes
      to_state: pending
      trigger: {}
  output_name: final_state
```

Prefer `trigger: {}` over emitting an event to yourself — simpler, and it avoids the race where
the machine consumes its own event before the transition is armed.

`moco-examples/state-machine-demo/src/`, `moco-examples/entity-workflow-demo/src/order-entity.yaml`

### `rules_engine`

```yaml
rules_engine:
  input_data:
    facts:
      applicant: {age: 25, income: 90000}
    run_mode: forward           # forward | backward
  rules:
    - id: adult
      if:
        expression: "{{applicant.age >= 18}}"
      then:
        set_facts:
          - applicant.is_adult: true
  output_name: derived
```

`moco-examples/moco-workflow-demo/src/rules-engine-basics-demo.yaml` (minimal),
`moco-examples/rules-engine-demo/src/rules-engine-demo.yaml` (with audit trail)

### `call` — invoke a function declared in this wfspec

```yaml
call:
  function: add                 # required — must name an entry in top-level `functions:`
  name: add-them
  input_data:
    a: "{{x}}"
    b: "{{y}}"
  output_name: total
```

A **function** is a reusable subset of a wfspec (`input_data` / `output_data` / `body`) declared
under the top-level `functions:` list and run as an inline child workflow:

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
```

Each call runs in a **fresh context**, so a function cannot read or clobber the caller's
variables — only what is passed in is visible. Functions may call sibling functions. Reach for
this instead of a separate child wfspec file when the logic is small and only this spec needs it.

**`output_name` binds the function's whole `output_data` dict.** Above, `total` is `{'sum': 120}`
— not `120`. Read the field (`total['sum']`) or destructure with `output_data` at the call site.
Getting this wrong surfaces later as
`'>' not supported between instances of 'dict' and 'int'` in whatever transform consumes it.

`moco-examples/moco-workflow-demo/src/functions-demo.yaml`,
`moco-examples/tech-signal-feed/src/market-data-feed.yaml`

---

## Special variables

| Variable | Is |
|---|---|
| `_` | Root of the workflow context |
| `_raw_output` | The step's raw output — only inside `output_data` |
| `iter_item` | Current iteration item (== `iter_items[-1]`) |
| `iter_items` | All iteration items, nested |
| `__sys_info__` | System info — e.g. `__sys_info__["workflow_id"]` |
| `__user_info__` | User info — e.g. `__user_info__["user_uuid"]` |

## Top-level wfspec fields

The complete set, from the schema. Only `wfspec_name` is strictly required, but every real spec
sets `wfspec_version` and `body` too.

| Field | Purpose |
|---|---|
| `wfspec_name` | **Required.** kebab-case identifier |
| `wfspec_version` | semver; start new specs at `1.0.0` |
| `body` | The root statement |
| `context` | Constants and optional-with-default values |
| `input_data` | Expected inputs; required ones are `null` |
| `output_name` / `output_data` | Shape the workflow's output |
| `functions` | Reusable functions invoked by the `call` statement |
| `wfspec_imports` | Pull `context` from a body-less shared-config spec |
| `tags` | Free-form labels |
| `description` | Prefer a YAML comment — `description` costs runtime overhead |
| `run_as_user_id` | Run under a specific identity |

`execute_options` is **not** top-level — it belongs to the `workflow` statement (and, via
`entity_child_workflow`, to `emit_event`). It carries `workflow_id` and
`entity_workflow_args.is_entity_workflow: true` for long-lived entity workflows with
deterministic IDs.

## Every statement, for reference

`abort`, `activity`, `call`, `continue_as_new_checkpoint`, `emit_event`, `iteration`, `parallel`,
`rules_engine`, `sequence`, `state_machine`, `transform`, `wait_for`, `workflow` — 13 in total.
Anything else is not a statement.

`continue_as_new_checkpoint` restarts the workflow with fresh history and is required for
unbounded loops. Fields: `name`, `condition`, `serialize_data_context`, `enforce` (tests only).
`moco-examples/moco-workflow-demo/src/continue-as-new-demo.yaml`
