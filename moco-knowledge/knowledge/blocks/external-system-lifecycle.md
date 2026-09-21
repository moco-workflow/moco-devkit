---
id: external-system-lifecycle
what: Driving a multi-step external resource — acquire, use, release — as separate activities with their own retry postures.
use_when: An external operation has phases that differ in how safely they can be retried.
inputs: []
outputs: []
follows: [phase-specific-retry-posture, mock-external-calls-in-tests, comment-freely]
pairs_with: [abort-control-flow, parallel-fan-out]
from: "k8s.* / gdrive.* / http.request"
seen_in: [k8s-demo, gdrive-demo, web-crawler-demo]
status: active
---

# External system lifecycle

Resist fusing "run a Kubernetes job" into one activity. Split it, so each phase gets the retry and
timeout posture it actually needs.

## Snippet

```yaml
- activity:
    type: k8s.apply
    name: create-job
    retry_policy: {timeout_sec: 60, max_attempts: 3}
- activity:
    type: k8s.wait
    name: await-job
    retry_policy: {timeout_sec: 900}      # a long wait, not a retried one
- activity:
    type: k8s.logs
    name: fetch-logs
    retry_policy: {timeout_sec: 60, max_attempts: 2}
- activity:
    type: k8s.delete
    name: cleanup
    retry_policy: {timeout_sec: 60, max_attempts: 1}
```

## Watch out

- **Timeouts and retries go under `retry_policy`, not on the activity.** `timeout_sec` and
  `max_retry_attempts` are not `ActivityRecord` fields; `retry_policy` carries `timeout_sec`,
  `max_attempts`, `heartbeat_timeout_sec`, `backoff_coefficient` and friends. Getting this wrong
  produces the misleading `/body` validation cascade rather than a message naming the field.

- **The phases differ in retry safety and that is the point.** A create may be retryable; a wait
  should not loop; a cleanup should try but never block the run. One fused activity forces one
  posture on all of them.
- Make the release step resilient and non-fatal. A failed cleanup should be visible, not the
  thing that fails an otherwise successful workflow.
- Mock every phase in tests (rule `mock-external-calls-in-tests`).
  `moco-examples/k8s-demo/tests/k8s-job-run.test.yaml` covers the whole lifecycle with no cluster
  — that is the bar.
- Comment *why* the phases are split. `k8s-demo` does this in its header and it is the reason the
  spec is readable a year later.
- Same shape for `gdrive.*` (create folder, upload, list, download, verify, delete) and for a
  browser session (`playwright.browser.create` ... `close`).
