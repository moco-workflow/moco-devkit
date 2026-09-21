# Moco capability map

A human-readable index over the **182 activity types in 19 families** that the engine accepts.
Use it to form a hypothesis fast; then confirm with the script, which reads the schema:

```bash
scripts/list-activities.sh --exists <type>     # is it real?
scripts/list-activities.sh --schema <type>     # what inputs does it take?
scripts/list-activities.sh --grep <term>       # search
```

**The map is a guide; the schema is the truth.** Never put an activity type in a plan without
`--exists` returning EXISTS. Counts here are from the shipped schema and shift as activities are
added — if the script disagrees with this file, the script is right.

---

## The families

### `builtin` — 92 types, but read this before reaching in

**75 of the 92 are `builtin.deploy.*`** — platform administration (apikeys, auth, namespaces,
packages, users, groups, wfspec versions, deployments). They exist so Moco can administer itself;
a normal workflow almost never calls them. Reach for them only when the workflow's *subject* is
the platform.

The 17 that matter for ordinary authoring:

| Sub-family | Types | What it's for |
|---|---|---|
| `builtin.state.*` | 8 — `set_state`, `get_state`, `get_state_with_ts`, `del_state`, `list_states`, `list_namespaces`, `update_topic`, `delete_by_topic` | **The workhorse.** Durable key/value state grouped into namespaces. This is how Moco workflows remember anything across steps, runs, or workflows. By far the most-used family in the example corpus. |
| `builtin.secret.*` | 4 — `get`, `list`, `upload`, `delete` | Credentials. Never inline a secret in a wfspec. |
| `builtin.event.*` | 2 — `emit_debug_event`, `emit_metric_event` | Observability. Distinct from the `emit_event` *statement*, which does workflow-to-workflow messaging. |
| `builtin.*` | 3 — `delay`, `now`, `execute_workflow` | `delay` for timers/backoff (very common); `now` for a deterministic clock; `execute_workflow` to invoke another workflow as an activity. |

### Talking to the outside world

| Family | Types | Reach for it when |
|---|---|---|
| `http` | 1 — `http.request` | Any REST/HTTP API. **The general-purpose escape hatch.** |
| `mcp` | 1 — `mcp.call_tool` | Any tool exposed by an MCP server. **The other general-purpose escape hatch** — it makes a large surface reachable without a new activity. |
| `shell` | 1 — `shell.run` | Local commands, scripts, CLIs. Last resort: least portable, hardest to test. |
| `sql` | 2 — `query`, `execute` | Relational databases. `query` reads, `execute` writes. |
| `email` | 1 — `email.send` | SMTP, with attachments/CC/BCC. |
| `graphql` | 1 — `graphql.subscribe` | GraphQL **subscriptions** only — there is no `graphql.query`; a plain GraphQL query goes over `http.request`. |
| `websocket` | 1 — `websocket.subscribe` | Streaming socket feeds. |
| `kafka` | 2 — `publish`, `consume` | Kafka messaging. |
| `rabbit` | 2 — `publish`, `receive` | RabbitMQ messaging. |
| `gdrive` | 6 — `create_folder`, `upload`, `download`, `list`, `get_metadata`, `delete` | Google Drive file lifecycle. |
| `k8s` | 8 — `apply`, `get`, `list`, `delete`, `exec`, `logs`, `wait`, `scale` | Kubernetes. Note these are *separate* activities on purpose, so each phase gets its own retry posture. |

### AI and retrieval

| Family | Types | Reach for it when |
|---|---|---|
| `openai` | 1 — `openai.chat.completions` | A single LLM call with a prompt. |
| `claude_agent` | 1 — `claude_agent.query` | A full multi-turn agent loop with tools inside one activity. Runs on the dedicated `agent` worker; can be long-running. |
| `llama_index` | 7 — `index_docs`, `index_files`, `index_web`, `index_site`, `index_github`, `index_gdrive`, `query` | RAG. Index once, then `query`. |
| `langfuse` | 2 — `create_score`, `run_experiment` | LLM evaluation and scoring. |

### Browser automation

| Family | Types | Reach for it when |
|---|---|---|
| `playwright` | 26 | Browser driving — `browser.*`, `page.*`, `element.*`. The newer, larger surface. |
| `selenium` | 23 | Same job, older surface. Prefer `playwright` for new work unless matching an existing spec. |

### Authorization

| Family | Types | Reach for it when |
|---|---|---|
| `authz` | 4 — `check_privilege`, `list_resources`, `get_resource_policy`, `impersonate_user` | Permission checks inside a workflow. |

---

## What is NOT an activity

A capability gap is often not a gap at all — several things people look for an activity for are
**statements** in the wfspec language, and searching the activity enum for them turns up nothing:

| You want to... | Not an activity — use the statement |
|---|---|
| Compute, reshape, or extract data | `transform` |
| Call another workflow | `workflow` (or `builtin.execute_workflow` as an activity) |
| Stop early / validate / break a loop | `abort` (types: `abort`, `terminate`, `raise`, `break`, `break_iteration`) |
| Wait for an external event | `wait_for` |
| Send an event to another workflow | `emit_event` |
| Branch, loop, or fan out | `sequence`, `parallel`, `iteration`, `state_machine`, `rules_engine` |
| Schedule / delay | `builtin.delay`, or a state machine with a timer |

Long-running, resumable, human-in-the-loop, and "wake up later" behaviours come from the runtime
(`state_machine` + `wait_for` + `continue_as_new`), not from a special activity.

---

## The escape-hatch ladder

Work down this list before writing "no capability exists". Only the last rung is not self-service.

1. **A native activity** — `--grep` the enum.
2. **`mcp.call_tool`** — is the system reachable as an MCP tool?
3. **`http.request`** — does it have any HTTP API?
4. **`shell.run`** — is there a CLI?
5. **Compose** — several activities plus `transform`/child workflows.
6. **A new custom activity** — platform work in `moco-core`, requires `make gen-catalog && make gen-schema`. This is the only rung the workflow author cannot do alone, so say so explicitly when a plan depends on it.
