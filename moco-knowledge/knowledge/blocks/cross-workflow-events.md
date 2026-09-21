---
id: cross-workflow-events
what: Workflow-to-workflow messaging — emit_event to send, wait_for to receive.
use_when: Two workflows must coordinate — request/reply, fan-out to workers, notifying a long-lived process.
inputs:
  - {name: topic, type: str}
  - {name: event_type, type: str}
  - {name: target_workflow_id, type: str}
  - {name: data, type: any}
outputs:
  - {name: event, type: dict}
follows: [timeout-sec-is-number-literal, self-emit-needs-async-delay]
pairs_with: [state-machine-transitions, entity-workflow, async-activity-token]
from: "emit_event + wait_for"
seen_in: [client-server-demo, entity-workflow-demo, moco-agent, rmq-demo, async-activity-demo, trade-simulator]
status: active
---

# Cross-workflow events

## Snippet

Request, then wait for the correlated reply:

```yaml
- emit_event:
    name: submit-request
    input_data:
      topic: tasks
      event_type: submit
      target_workflow_id: "{{server_id}}"
      data:
        req_id: "{{req_id}}"
        payload: "{{payload}}"

- wait_for:
    name: await-reply
    event:
      topic: tasks
      event_type: result
      match_expression: "{{event.get('data', {}).get('req_id') == req_id}}"
    timeout_sec: 300
    output_name: reply
```

## Watch out

- **Always match on a correlation id.** A `wait_for` with no `match_expression` takes the next
  event on the topic — which, with more than one client in flight, is somebody else's reply. This
  is the defining bug of this pattern and it only shows up under concurrency.
- `timeout_sec` is a number literal (rule `timeout-sec-is-number-literal`), and a `wait_for`
  without one can hang forever.
- `emit_event` is fire-and-forget. If the target is not running the event is simply lost — use
  `entity_child_workflow` (see `entity-workflow`) when the target must exist.
- Decide the topic namespace up front. Topics are global; two unrelated features on `default`
  will interfere.
- `emit_event` carries `suppress_error` when a failed send genuinely should not fail the
  workflow. Use it deliberately, not as a default.
