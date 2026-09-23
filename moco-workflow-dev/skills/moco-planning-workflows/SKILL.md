---
name: moco-planning-workflows
description: "Analyzes a request, checks it against Moco's real activity catalog, and returns a feasibility verdict plus a build plan. Use BEFORE writing any wfspec YAML when: (1) the user describes something they want automated and it is not yet clear Moco can do it, (2) someone asks 'can Moco do X' or 'is X possible as a workflow', (3) a request names an external system (Slack, Jira, S3, a database, a browser, an LLM) and you need to know what activity covers it, (4) scoping or estimating workflow work, or (5) you are about to start building and want the decomposition settled first."
---

# Planning a Moco workflow

Answer *can Moco do this, and if so how* **before** a line of YAML exists.

The failure this prevents is expensive and common: building a workflow around an activity type
that was never real, or spending hours on a request that a workflow engine was the wrong tool for.
Both are cheap to catch here and costly to catch later.

Produce two things: a **verdict** and, unless the verdict is POOR FIT, a **build plan**.

---

## Step 1 — Pin down the request

Extract these. Ask the user only about what genuinely changes the design; infer the rest and state
your assumption.

| | |
|---|---|
| **Trigger** | What starts it — an API call, a schedule, an event, another workflow, a human? |
| **Inputs** | What it needs to start. Which are required vs. defaulted? |
| **Outputs** | What it produces, and who consumes it. |
| **External systems** | Every system it must read from or write to. **List these explicitly — Step 2 is a lookup over this list.** |
| **Control flow** | Branching? Looping over a collection? Parallel fan-out? Retries? |
| **Lifetime** | Seconds, or long-running? Does it wait for an external event, a human, or a timer? |
| **State** | Does anything need to persist across steps, runs, or workflows? |

A long-lived, waits-for-things, resumable shape is a strong signal for Moco. A single synchronous
call with no orchestration is a signal against it.

## Step 2 — Map each external system to a real activity

**Never do this from memory.** The wfspec JSON schema is the authoritative inventory —
183 activity types across 19 families — and this skill ships a script that reads it without
pulling the whole ~8,000-line schema into context:

```bash
scripts/list-activities.sh                    # families + counts — start here
scripts/list-activities.sh --grep slack       # search for a capability
scripts/list-activities.sh --family k8s       # everything in one family
scripts/list-activities.sh --exists k8s.apply # is this type real? (exit 1 if not)
scripts/list-activities.sh --schema http.request  # what inputs does it take?
```

Read [references/capability-map.md](references/capability-map.md) for what each family is for and,
importantly, **what is not an activity at all** — `transform`, `abort`, `wait_for`, `emit_event`,
and the composite statements are wfspec *statements*, so searching the activity enum for "loop" or
"branch" or "wait" correctly turns up nothing. Do not read that as a capability gap.

Two things the map will tell you that are easy to get wrong:

- **75 of the 93 `builtin` activities are `builtin.deploy.*`** platform administration. Ordinary
  workflows use the other 18 — above all `builtin.state.*` (durable namespaced key/value state,
  the single most-used family in the corpus) and `builtin.delay`.
- **`graphql` has only `subscribe`.** A plain GraphQL query goes over `http.request`.

## Step 3 — Walk the escape-hatch ladder before calling anything a gap

No native activity does **not** mean infeasible. Work down this list; stop at the first rung that
works:

1. **Native activity** — `--grep` the enum.
2. **`mcp.call_tool`** — reachable as an MCP tool?
3. **`http.request`** — does it have any HTTP API?
4. **`shell.run`** — is there a CLI?
5. **Compose** — several activities plus `transform` and child workflows.
6. **A new custom activity** — platform work in `moco-core`, needing `make gen-catalog && make gen-schema`.

Rung 6 is the only one the workflow author cannot do alone. If the plan depends on it, say so
plainly and name what has to be built — do not bury it.

Getting this backwards in either direction is the trap: declaring "Moco can't talk to Slack"
(it can, via `http.request` or `mcp.call_tool`) is as wrong as promising a native `slack.post`
that does not exist.

## Step 4 — Give the verdict

State one of these up front, in one line, before any detail:

| Verdict | Means | What to include |
|---|---|---|
| **FEASIBLE** | Every interaction maps to a real activity or statement. | Go straight to the plan. |
| **FEASIBLE WITH GAPS** | The core maps, but some interactions need an escape hatch or new platform work. | Name each gap, which rung covers it, and what it costs. Then the plan. |
| **POOR FIT** | A workflow engine is the wrong tool. | Say why in a sentence and say what fits better. No plan. Do not pad it into a reluctant yes. |

Honest POOR FIT signals: a single synchronous request/response with no orchestration, retries, or
durable state; sub-second latency budgets; heavy in-process CPU or large in-memory data crunching;
anything needing a UI. Say it plainly — a wrong yes here wastes far more of the user's time than a
direct no.

## Step 5 — Write the plan

Only for FEASIBLE / FEASIBLE WITH GAPS:

```markdown
## Verdict
FEASIBLE — all six external interactions map to existing activities.

## Decomposition
- `<name>.wfspec.yaml` (parent) — <responsibility>
- `<child>.wfspec.yaml` — <responsibility, and why it is split out>

## Steps
| # | Step | Statement | Activity type | Produces |
|---|---|---|---|---|
| 1 | validate-input | abort | — | (guards) |
| 2 | fetch-orders | activity | `http.request` | `orders` |
| 3 | score-each | iteration (parallel) | — | `scored` |
| 4 | persist | activity | `builtin.state.set_state` | — |

## Data flow
input → ... → output

## Start from
`moco-examples/<demo>/src/<spec>.yaml` — <why it is the closest existing thing>

## Gaps / risks
- <named gap, which ladder rung covers it, what it costs>

## Test plan
- unit: <the branching transforms worth pinning>
- integration: <the end-to-end path, with which activities mocked>
```

Two rules for the plan:

- **Every activity type in the table must have passed `--exists`.** A hallucinated type here is
  the exact failure this skill exists to prevent, and it propagates straight into the YAML.
- **Start from an existing spec, not a blank canvas.** The demos in `moco-examples/` are the
  corpus; `moco-workflow-demo/` alone has ~25 single-feature specs, each with a matching test.
  If the **moco-knowledge** plugin is installed, use `moco-consulting-kb` to match the request
  against `examples-index.yaml` and pull the relevant blocks. If it is not installed, skim
  `moco-examples/` directly. Either way, name a concrete file to copy from.

## Step 6 — Hand off

Present the verdict and plan, then stop and let the user confirm before building. On confirmation,
hand to **`moco-developing-workflows`** to write the YAML, then **`moco-validating-workflows`** to
drive it to green.

---

## Do not

- Name an activity type you have not confirmed with `--exists`.
- Conclude "no capability" without walking the escape-hatch ladder.
- Search the activity enum for control flow — those are statements.
- Turn a POOR FIT into a hedged yes to be agreeable.
- Write YAML. That is the next skill's job; this one produces the plan.
