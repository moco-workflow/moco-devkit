---
name: moco-validating-workflows
description: "Drives a Moco wfspec to green — an iterative loop of schema validation, runtime execution, tests, and review, fixing the spec each pass. Use when: (1) a wfspec is failing validation, a run, or its tests, (2) you just wrote a spec and want it working end to end, (3) the user says validate, check, fix, debug, or 'make this work', (4) classifying a confusing moco error, or (5) finishing a build before handing it over."
---

# Validating a Moco workflow

One loop, four phases, run until the spec is genuinely green. Do not declare success partway.

```
for iteration in 1..15:

  A. SCHEMA     moco validate <file>
                 └─ errors → classify → fix → restart iteration

  B. RUNTIME    moco run <file> --input '<json>'
                 └─ code error → classify → fix → restart
                 └─ infra error → STOP and surface (see below)

  C. TESTS      moco test 'tests/**/*.test.yaml'
                 └─ failures → fix → restart

  D. REVIEW     moco-workflow-reviewer agent   (if moco-knowledge is installed)
                 └─ FAIL → fix → restart
                 └─ PASS → done
```

Phase D is a gate, not a formality: it is the only phase that checks the spec against the
authoring rules rather than just against the engine. Without the **moco-knowledge** plugin, do the
equivalent by hand — re-read the spec against the non-negotiables in `moco-developing-workflows`
before calling it done.

## Phase A — schema

```bash
moco validate path/to/flow.wfspec.yaml
```

Local, offline, no auth. Reports `path`, `line`, and `message` per error, and exits non-zero.

**The schema is the source of truth.** If it says a property is not allowed or a type is wrong, it
is right — do not dismiss a diagnostic as a false positive. Re-run after every fix.

## Phase B — runtime

```bash
moco run path/to/flow.wfspec.yaml --input '{"order_id":"A-1"}'
moco run path/to/flow.wfspec.yaml --in-memory     # no server needed
moco run path/to/flow.wfspec.yaml --debug         # traces from a deployed spec
```

Variables whose names end in `#` stream their values here — add them liberally while debugging,
including from child workflows.

## Phase C — tests

```bash
moco test 'tests/**/*.test.yaml'
moco test --in-memory --verbose
```

Create tests if none exist. **Never edit a test to make a failing spec pass** unless the test is
demonstrably wrong — say so explicitly and explain why before touching it.

## Error classification

Match the signal, then apply the fix. The mechanical classes need no reasoning; the last one does.

| Signal | Class | Fix |
|---|---|---|
| Property not allowed / unknown field | SCHEMA | Check the real field name — activity inputs via `list-activities.sh --schema <type>` |
| `name X is not defined` | DATA_FLOW | The variable is not in context yet; find the step that should produce it |
| Syntax error inside `{{ }}` | EXPRESSION | Fix the Python; check bracket and quote balance |
| Required input not provided | MISSING_INPUT | Add the field from the activity's input schema |
| Expected list, got str (or similar) | TYPE_ERROR | Wrap or unwrap; check `iter_item` access |
| `mapping values are not allowed here` | YAML_SYNTAX | Quoting — a `{` or `:` in an unquoted scalar |
| `NoneType` in arithmetic or comparison | EAGER_EVAL | `output_data` evaluates every entry; make it None-safe with `(x or 0)` or an `is not None` guard |
| A cascade of `Missing required property: transform/abort/activity/... at /body` plus `Unknown property: sequence at /body` | BAD_ACTIVITY (usually) | **Read this row before anything else.** See below — the message does not name the real culprit |
| Timeout, connection refused, auth, no session | INFRA | See below — do **not** keep looping |
| Runs but produces the wrong answer | LOGIC | Re-read the requirement and reason about intent; this is the only class you cannot fix mechanically |

## The misleading cascade — the one error worth memorising

`body` is a union of the 13 statement types. When **anything** nested inside it fails to match,
the whole union fails, and the validator reports every branch it tried — at every level, up to
the root. You get a wall like this:

```
• Missing required property: transform at /body
• Unknown property: sequence at /body
• Missing required property: abort at /body
• Unknown property: sequence at /body
...
```

**`sequence` is not actually unknown, and `/body` is not actually where the problem is.** The real
cause is somewhere deeper and is never named. Verified cause: a single invalid activity `type:`
(e.g. `slack.post`) produces exactly this output, with no mention of the activity at all.

When you see it:

1. **Check every activity type first** — `list-activities.sh --exists <type>` for each one. This
   is the most common cause by a wide margin, and it is the cheapest to rule out.
2. Then check required fields on nested statements — `join_type` on `parallel`, `iter_type`/
   `input_data`/`body` on `iteration`, `message` on `abort`, `wfspec` on `workflow`,
   `function` on `call`.
3. Bisect if it is still unclear: cut the body down to a minimal `sequence` with one `transform`,
   confirm it validates, then add statements back until it breaks.

Do not spend time "fixing" `/body`. There is nothing wrong with it.

## Two stopping rules

**Infra failures stop the loop.** If `moco run` cannot execute at all — auth, no server, connection
refused — retry once. If it still will not run, stop and tell the user what is blocking. There is
nothing to validate until the spec actually runs, and iterating burns time without information.
This is different from a code error, which stays in the loop.

**The same error three times means stop.** If a fix has not moved the error in three attempts, you
are guessing. Say what you tried and ask.

## Finishing

Report honestly and specifically:

- what passes, and what command proves it;
- anything still failing, with the actual output — not a summary of it;
- anything skipped, and why.

If tests fail, say so. A spec that validates but fails its tests is not done.
