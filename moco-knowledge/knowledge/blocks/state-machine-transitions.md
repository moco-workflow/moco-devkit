---
id: state-machine-transitions
what: A long-lived, event-driven finite state machine with states, on_enter work and transitions.
use_when: The workflow is long-running, resumable, waits on external events, or is naturally described as states rather than steps.
inputs:
  - {name: initial_state, type: str}
  - {name: states, type: list}
  - {name: transitions, type: list}
  - {name: event_source_topic, type: str}
outputs:
  - {name: final_state, type: str}
follows: [prefer-direct-transition, self-emit-needs-async-delay, continue-as-new-for-unbounded-loops, named-steps-are-testable]
pairs_with: [cross-workflow-events, entity-workflow, continue-as-new, namespace-state-store]
from: state_machine
seen_in: [state-machine-demo, entity-workflow-demo, client-server-demo, rmq-demo, trade-simulator, web-crawler-demo, tech-signal-feed]
status: active
---

# State machine transitions

## Snippet

```yaml
state_machine:
  initial_state: pending
  event_source_topic: order_events
  states:
    - name: pending
      on_enter: {...}
      timeout_sec: 600
    - name: shipped
    - name: done
      is_terminal: true
  transitions:
    # direct — fires as soon as on_enter finishes; no event involved
    - from_state: pending
      to_state: shipped
      trigger: {}

    # event-driven
    - from_state: shipped
      to_state: done
      trigger:
        event_type: delivered
        condition: "{{event.get('data', {}).get('ok')}}"
  output_name: final_state
```

Branch by giving two transitions from the same state mutually exclusive conditions.

## Watch out

- **Prefer `trigger: {}` over emitting an event to yourself** (rule `prefer-direct-transition`).
  It is simpler and cannot race. Only reach for a self-emit when the transition genuinely must be
  driven by a message — and then see `self-emit-with-delay`.
- A state machine consumes events on its `event_source_topic`. Two machines sharing a topic will
  steal each other's events unless every transition condition discriminates on the payload.
- `is_terminal: true` is what ends the machine. Without a reachable terminal state it runs until
  its timeout.
- Conditions read the incoming event through `event`, and the surrounding workflow context by
  name. Use `event.get('data', {}).get('x')` rather than indexing — a malformed event should not
  crash the transition.
- Long-lived machines accumulate history. Pair with `continue-as-new`.
