---
name: moco-testing-workflows
description: "Writes and runs Moco workflow tests — unit tests over a single named step, integration tests over a whole wfspec, activity mocking, and the four expectation types. Use when: (1) asked to test a workflow or add test cases, (2) writing or fixing a *.test.yaml file, (3) explaining test syntax, mocking, or assertions, (4) running `moco test` or debugging a failing test, or (5) deciding what in a workflow is worth covering."
---

# Testing Moco workflows

Two kinds of test, both YAML, both run by `moco test`.

| | `unit-test` | `integration-test` |
|---|---|---|
| Scope | One **named step**, in isolation | The whole wfspec, end to end |
| Needs | `wfspec.content` (the spec inline) | `wfspec.name` (deployed or local) |
| Groups by | `test_groups[].step_name` | flat `test_cases` |
| Good for | Branching logic, math, text generation | Wiring, data flow, the happy path |

A step must have a `name:` to be unit-testable. If the logic you want to pin has no name, name it.

## Running

```bash
moco test                          # defaults to tests/**/*.test.yaml in cwd
moco test tests/my-flow.test.yaml  # one file
moco test 'tests/**/*.test.yaml'   # a glob
moco test --in-memory              # in-memory runtime, no server
moco test --verbose                # per-test progress and server logs
```

## Unit test

```yaml
# yaml-language-server: $schema=../workflowspec_test_schema.json
test_type: unit-test

wfspec:
  name: order-scorer
  content: |                       # REQUIRED for unit tests — the spec inline
    wfspec_name: order-scorer
    wfspec_version: 1.0.0
    body:
      transform:
        name: score-order          # the step under test
        output_data:
          - tier: "{{'gold' if spend > 1000 else 'standard'}}"

test_groups:
  - step_name: score-order
    test_cases:
      - id: spend-above-threshold
        input: {spend: 1500}
        expect:
          output:
            - tier: gold
      - id: spend-at-boundary      # test the boundary, not just the middle
        input: {spend: 1000}
        expect:
          output:
            - tier: standard
```

## Integration test

```yaml
# yaml-language-server: $schema=../workflowspec_test_schema.json
test_type: integration-test

wfspec:
  name: order-pipeline

test_cases:
  - id: happy-path
    input: {order_id: "A-1"}
    mocks:
      - step_name: fetch-order     # stub the external call
        _raw_output: {id: "A-1", spend: 1500}
    expect:
      output:
        - tier: gold
      assert:
        - "{{ len(items) > 0 }}"
```

## Required fields

- Suite: `test_type`, `wfspec` (with `name`), and `test_cases` (integration) or `test_groups` (unit).
- Unit suites additionally require `wfspec.content`.
- Test case: `id`, `input`, `expect`.
- Mock: `step_name`, `_raw_output`.
- Test group: `step_name`, `test_cases`.

## The four expectation types

Combine freely inside one `expect:`; all of them must hold.

```yaml
expect:
  output:                          # named output variables match
    - tier: gold
    - total: "{{ 1500 * 1.1 }}"

  assert:                          # arbitrary expressions, all must be True
    - "{{ len(results) == 3 }}"
    - "{{ status == 'ok' }}"

  terminate:                       # the workflow stopped gracefully via abort
    terminate_message: "No orders today"   # null matches any message

  error:                           # the workflow failed
    error_type: ValidationError            # null matches any type
    error_message: "order_id is required"  # null matches any message
```

`output` is for exact values; `assert` is for anything shape- or threshold-based. Use `terminate`
for a `type: terminate` abort and `error` for `abort`/`raise`.

## Mocking

A mock short-circuits a step by `step_name` and returns `_raw_output` instead of running it.

```yaml
mocks:
  - step_name: call-payment-api
    _raw_output: {status: approved, txn: "t-9"}
  - wfspec_name: child-scorer      # optional — target a step in a child workflow
    step_name: score
    _raw_output: {score: 0.91}
```

Mock every external call in an integration test. A test that needs real credentials, a cluster, or
the network is not a test you can run in CI — `moco-examples/k8s-demo/tests/k8s-job-run.test.yaml`
is the model: a full Kubernetes lifecycle covered with no cluster at all.

## What to cover

- **Every branch of a decision, including the boundary.** If wording or routing is chosen by a
  threshold or a sign, there is a case at `==` as well as either side.
- **Guards.** One case per `abort`, asserting the specific `terminate`/`error`.
- **Non-trivial computation** — math, aggregation, text assembly.
- Put the case on the step that *makes* the decision. A downstream step fed pre-built input does
  not cover the branching logic upstream of it.

Skip rather than delete work in progress — `skip: true` on a case or a whole group.

## Traps

- **A unit test resolves every variable the step references**, not only the asserted ones. Supply
  all of them in `input:`, or the step errors before it runs and every assertion fails with the
  same unhelpful message.
- **Date and datetime inputs must be expression strings** — `"{{dt.date(2026,1,5)}}"`, not a bare
  YAML date. A raw YAML date arrives as a plain string and breaks any `.weekday()`, comparison, or
  arithmetic downstream.
- **`test_data:`** at suite level holds fixtures shared by cases; reach for it before pasting the
  same payload into every case.
- Use `verbose: true` on a single failing case rather than the whole suite.

## Reference

Full schema, every field and constraint:
**[references/test-schema-reference.md](references/test-schema-reference.md)**
JSON Schema: `workflowspec_test_schema.json` (in this directory)

Worked examples in the corpus: `moco-examples/task-manager/tests/` (10 tests plus a
`run-all-tests.yaml` aggregator), `moco-examples/moco-workflow-demo/tests/` (one per language
feature), `moco-examples/k8s-demo/tests/k8s-job-run.test.yaml` (fully mocked integration).

Runners, if you need to reason about failures: `sys.run_test.unit`, `sys.run_test.integration`,
`sys.run_test.validate_test_case_expect`, `sys.run_test.format_test_output`.
