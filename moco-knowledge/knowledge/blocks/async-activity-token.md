---
id: async-activity-token
what: An activity that returns a token immediately and delivers its real result later.
use_when: The work outlives a normal activity timeout — a long job, a callback, a human step.
inputs:
  - {name: async_mode, type: bool}
outputs:
  - {name: token, type: str}
follows: [timeout-sec-is-number-literal]
pairs_with: [cross-workflow-events, state-machine-transitions]
from: "activity with async_mode: true"
seen_in: [async-activity-demo]
status: active
---

# Async activity token

With `async_mode: true` an activity returns a token straight away instead of a result. The
workflow collects the result later — with `wait_for`, or by letting a state machine transition on
the completion event.

## Snippet

```yaml
- activity:
    type: http.request
    name: kick-off-job
    async_mode: true
    input_data: {...}
    output_name: job_token

- wait_for:
    name: await-job
    event:
      event_type: job_complete
      match_expression: "{{event.get('data', {}).get('token') == job_token}}"
    timeout_sec: 3600
    output_name: job_result
```

## Watch out

- The activity's immediate output is a **token, not a result**. Treating it as the answer is the
  obvious first mistake and produces confusing downstream type errors.
- Something external has to complete the token. If nothing does, the `wait_for` blocks until its
  timeout — so always set one, as a number literal.
- Match on the token (rule in `cross-workflow-events`), or concurrent runs will collect each
  other's results.
- For work measured in minutes a plain activity with a generous `timeout_sec` is simpler. Reach
  for async mode when the wait is genuinely open-ended.
- The state-machine variant is often cleaner for long waits — see
  `async-activity-demo/src/async-activity-state-machine.yaml`.
