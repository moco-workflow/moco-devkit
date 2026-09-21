---
id: self-emit-with-delay
what: Emitting an event to your own state machine without racing its transition, by emitting from a delayed async child.
use_when: A state machine must drive itself with an event and a direct trigger {} transition genuinely will not do.
inputs:
  - {name: topic, type: str}
  - {name: event_type, type: str}
outputs: []
follows: [self-emit-needs-async-delay, prefer-direct-transition]
pairs_with: [state-machine-transitions, cross-workflow-events]
from: "workflow (child_mode: async) + emit_event"
seen_in: []
status: active
---

# Self-emit with delay

**Try to avoid needing this.** A `trigger: {}` direct transition (see
`state-machine-transitions`) covers almost every case and cannot race.

## The problem

A state machine processes events on its `event_source_topic`. Emitting to that topic from inside
`on_enter` can be consumed *before* the transition is armed, so the event vanishes and the machine
sits in its current state forever. It is intermittent and load-dependent, which makes it painful
to diagnose after the fact.

## Snippet

Emit from a child workflow that delays first, so the parent's transition is ready:

```yaml
- workflow:
    name: self-emit
    wfspec:
      content: "{{ emit_event_wfspec }}"   # inline spec: delay, then emit
    child_mode: async
    input_data:
      topic: my_topic
      event_type: my_event
      target_workflow_id: "{{ workflow_id }}"
      data: {}
```

## Watch out

- The child must be `async`. A `sync` child makes the parent wait for the emit, which
  reintroduces the ordering problem.
- The delay is a guess about a race. If you find yourself tuning it, that is a strong sign the
  transition should have been a `trigger: {}` instead.
- Documented in `moco-examples/CLAUDE.md` under State machine patterns. No demo in the corpus
  currently needs it — which is itself the argument for preferring direct transitions.
