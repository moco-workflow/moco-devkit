# Workflow patterns

Each pattern names a real spec in `moco-examples/` to copy. Read the spec — these sketches show
the shape, not every field.

---

## Sequential pipeline

The default. Fetch → transform → persist.

```yaml
body:
  sequence:
    elements:
      - activity: {type: http.request, name: fetch, input_data: {...}, output_name: raw}
      - transform: {name: shape, output_data: [{items#: "{{raw['data']}}"}]}
      - activity: {type: builtin.state.set_state, name: persist, input_data: {...}}
```

Copy: `moco-examples/moco-workflow-demo/src/sequence-demo.yaml`

## Fan-out / fan-in

Independent work at once. Use `parallel` for a fixed set of branches, `iteration` for a collection.

```yaml
parallel:
  join_type: and          # and = all must finish; or = first wins
  elements: [ {activity: {...}}, {activity: {...}} ]
  output_name: both
```

```yaml
iteration:
  iter_type: parallel
  join_type: and          # required for parallel iteration
  input_data: "{{tickers}}"
  body: {activity: {...}}
  output_name: quotes
```

Copy: `moco-examples/moco-workflow-demo/src/{parallel,iteration}-demo.yaml`,
`moco-examples/ai-agent-demo/multi-agent-research.yaml` (3 concurrent agents),
`moco-examples/sre-incident-agent/src/incident-response-agent.yaml`

## Guard / early exit

Validate before doing expensive work. The abort fires when `condition` is **True**.

```yaml
- abort:
    name: reject-missing-id
    type: raise
    condition: "{{order_id is None}}"
    message: "order_id is required"
    error: {code: VALIDATION_ERROR}

- abort:
    name: nothing-to-do
    type: terminate       # graceful — not an error
    condition: "{{not orders}}"
    message: "No orders today"
```

Put cheap guards before expensive fetches. Use `terminate` when "nothing to do" is a normal
outcome, `raise`/`abort` when it is a genuine failure.

Copy: `moco-examples/moco-workflow-demo/src/abort-demo.yaml`

## Conditional branch

There is no `if` statement — put `condition:` on the step.

```yaml
- transform:
    name: apply-discount
    condition: "{{spend > 1000}}"
    output_data: [{total#: "{{spend * 0.9}}"}]
```

## Durable state

`builtin.state.*` is the most-used family in the corpus. State is grouped into **namespaces**;
moving a key between namespaces is how status is modelled.

```yaml
- activity:
    type: builtin.state.set_state
    name: mark-submitted
    input_data: {namespace: submitted, key: "{{task_id}}", value: "{{task}}"}

- activity:
    type: builtin.state.list_states
    name: pending-tasks
    input_data: {namespace: submitted}
    output_name: pending
```

Copy: `moco-examples/task-manager/src/` — the canonical status-namespace architecture, 10 tests.

## Retry and timeout

Per-step, and worth varying by phase: a create can be safely retried, a delete should not loop
forever.

```yaml
activity:
  type: k8s.apply
  name: create-job
  retry_policy:            # NOT timeout_sec on the activity — that is not a field
    timeout_sec: 60        # number literal
    max_attempts: 3
```

Copy: `moco-examples/k8s-demo/src/k8s-job-run.yaml` — splits one logical operation into
`apply` → `wait` → `logs` → `delete` precisely so each phase gets its own retry posture. Its test
is fully mocked and needs no cluster.

## External system lifecycle

Same idea generally: model an external resource as acquire → use → release, with the release step
resilient.

Copy: `moco-examples/gdrive-demo/src/gdrive-demo.yaml` (create folder → upload → list → download →
verify → clean up)

## Long-lived entity workflow

One durable workflow instance per business entity, addressed by a deterministic ID.

```yaml
workflow:
  wfspec: {name: order-entity}
  child_mode: async
  execute_options:
    workflow_id: "order-entity:{{order_id}}"
    entity_workflow_args:
      is_entity_workflow: true
  input_data: {order_id: "{{order_id}}"}
```

Then drive it with **start-or-signal**, which starts it if needed and signals it if it is already
running:

```yaml
- emit_event:
    entity_child_workflow:
      wfspec: {name: order-entity}
      input_data: {order_id: "{{order_id}}"}
    input_data:
      topic: order_events
      event_type: ship
      target_workflow_id: "order-entity:{{order_id}}"
      data: "{{payload}}"
```

Copy: `moco-examples/entity-workflow-demo/src/` — two files, the smallest complete version.
Larger: `moco-examples/tech-signal-feed/src/`, `moco-examples/moco-agent/src/`.

## Event request/response

A client emits a request and waits for the reply; a server state machine handles it.

```yaml
- emit_event:
    input_data: {topic: tasks, event_type: submit, target_workflow_id: "{{server_id}}", data: {...}}
- wait_for:
    event:
      topic: tasks
      event_type: result
      match_expression: "{{event.get('data', {}).get('req_id') == req_id}}"
    timeout_sec: 300
    output_name: reply
```

Always match on a correlation id — otherwise you will consume someone else's reply.

Copy: `moco-examples/client-server-demo/src/{task-service-client,task-service-server}.yaml`

## State machine

For anything long-lived, event-driven, or resumable.

```yaml
state_machine:
  initial_state: waiting
  event_source_topic: order_events
  states:
    - {name: waiting}
    - {name: done, is_terminal: true}
  transitions:
    - from_state: waiting
      to_state: done
      trigger: {event_type: complete}
```

Prefer `trigger: {}` (fires when `on_enter` finishes) over emitting an event to yourself. A
self-emit on the machine's own `event_source_topic` can be consumed before the transition is
armed; if you truly need one, emit it from an `async` child that delays first.

Copy: `moco-examples/state-machine-demo/src/`

## Bounding history on a loop

A workflow that loops forever accumulates unbounded history. Drop a checkpoint that restarts it
with a fresh history, carrying the context forward.

```yaml
- continue_as_new_checkpoint:
    name: checkpoint
    condition: "{{not is_continue_as_new}}"   # fires when True
    serialize_data_context: true              # carry the context into the new run
```

The statement is `continue_as_new_checkpoint` — not `continue_as_new`. `enforce: true` forces the
restart regardless of history size and exists for tests; leave it off in real specs.

Copy: `moco-examples/moco-workflow-demo/src/continue-as-new-demo.yaml`,
`moco-examples/tech-signal-feed/src/market-data-feed.yaml`

## Child workflow as data resolver

Push a self-contained lookup into a child workflow so it can be tested and reused on its own.
See `moco-core/docs/workflow-as-data-resolver.md`.

Copy: `moco-examples/moco-workflow-demo/src/child-workflow-modes-demo.yaml`

## Shared constants

A body-less spec that exists only to carry `context`, pulled in via `wfspec_imports`.

Copy: `moco-examples/moco-workflow-demo/src/{wfspec-imports,shared-config}-demo.yaml`

## AI / agent steps

| Need | Activity |
|---|---|
| One LLM call | `openai.chat.completions` |
| A multi-turn agent loop with tools | `claude_agent.query` |
| RAG | `llama_index.index_*` then `llama_index.query` |
| Scoring / evaluation | `langfuse.*` |

Copy: `moco-examples/openai-demo/src/`, `moco-examples/claude-agent-demo/src/`,
`moco-examples/rag-demo/src/`, `moco-examples/ai-agent-demo/multi-agent-research.yaml`
