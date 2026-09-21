---
id: entity-workflow
what: One durable, long-lived workflow instance per business entity, addressed by a deterministic id.
use_when: State belongs to a thing (an order, a conversation, a security) that outlives any single request, and you want exactly one live instance per thing.
inputs:
  - {name: entity_id, type: str}
outputs: []
follows: [entity-workflow-deterministic-id, continue-as-new-for-unbounded-loops]
pairs_with: [state-machine-transitions, cross-workflow-events, namespace-state-store]
from: "workflow + execute_options.entity_workflow_args"
seen_in: [entity-workflow-demo, tech-signal-feed, moco-agent]
status: active
---

# Entity workflow

## Snippet

Start one:

```yaml
workflow:
  wfspec: {name: order-entity}
  child_mode: async
  execute_options:
    workflow_id: "order-entity:{{order_id}}"     # deterministic — this IS the identity
    entity_workflow_args:
      is_entity_workflow: true
  input_data:
    order_id: "{{order_id}}"
```

Drive it with **start-or-signal**, which starts it if it is not running and signals it if it is:

```yaml
- emit_event:
    entity_child_workflow:
      wfspec: {name: order-entity}
      input_data: {order_id: "{{order_id}}"}
      child_mode: async
    input_data:
      topic: order_events
      event_type: ship
      target_workflow_id: "order-entity:{{order_id}}"
      data: "{{payload}}"
```

## Watch out

- **The `workflow_id` must be deterministic and derived from the entity key** (rule
  `entity-workflow-deterministic-id`). A timestamp or random suffix creates a second live
  instance for the same entity, which is the whole failure mode this pattern exists to prevent.
- Use the same `workflow_id` convention everywhere — `entity-name:{{key}}`. A caller that builds
  the id differently silently starts a duplicate.
- `entity_child_workflow` on `emit_event` is the safe way to talk to one. A bare `emit_event` to
  a `target_workflow_id` that is not running goes nowhere.
- Entity workflows are long-lived by definition, so they need `continue-as-new`.
- Read `entity-workflow-demo` (two files) before the larger examples — `tech-signal-feed` and
  `moco-agent` layer real business logic on top and are harder to learn the pattern from.
