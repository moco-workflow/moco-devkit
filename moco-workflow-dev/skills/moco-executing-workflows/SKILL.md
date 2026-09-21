---
name: moco-executing-workflows
description: "Runs Moco workflows and activities with the moco CLI — run, start, test, activity, status, history, cancel, terminate, publish, state, secret, session, schema, config, login. Use when: (1) executing a workflow locally or by deployed name, (2) running a single activity, (3) checking status or history of a run, (4) cancelling or terminating, (5) publishing a workflow package, or (6) unsure which moco command or flag to use."
---

# Running Moco workflows

## Three execution paths — pick the right one

These are easy to confuse and do different things:

| Command | Runs | Use when |
|---|---|---|
| `moco run <file-or-name>` | A whole workflow | The normal case |
| `moco run <file> --activity` | The spec in standalone-activity mode | Rare; ignored with `--in-memory` |
| `moco activity run <type>` | **One activity**, no workflow | Probing an activity's behaviour or inputs |

`moco run` takes either a local `.yaml`/`.yml` path (child workflow files are bundled
automatically) or the name of a deployed workflow.

## Synchronous vs asynchronous

```bash
moco run <file-or-name>     # waits, prints the result
moco start <file-or-name>   # returns a workflow ID immediately
```

`start` is Temporal-only — no `--in-memory`, no `-o/--output`. Use it for long-running workflows,
then track with `status` / `history` and stop with `cancel` / `terminate`.

## `moco run`

```bash
moco run flow.wfspec.yaml --input '{"order_id":"A-1"}'
moco run flow.wfspec.yaml --in-memory          # single process, no server
moco run my-deployed-flow --debug              # traces from a deployed spec
moco run flow.wfspec.yaml -o result.json
```

| Flag | Meaning |
|---|---|
| `-i, --input <json>` | Input data |
| `--in-memory` | In-memory runtime instead of Temporal |
| `-t, --timeout <seconds>` | `0` = no timeout (the default for `run`) |
| `-o, --output <file>` | Write the result to a file |
| `--debug` | Verbose logging **and** trailing-`#` traces for deployed workflows |
| `--trace` | OpenTelemetry tracing |
| `--activity` | Standalone-activity execute mode |
| `--user-id`, `--user-org`, `--tier` | Identity and tier overrides |
| `--auth <oauth\|apikey>` | Force an auth mode |

**Trailing-`#` traces:** running a local file, they print automatically. Running a deployed
workflow by name, you need `--debug`. Child workflow traces are collected either way.

## `moco start` and tracking a run

```bash
moco start flow.wfspec.yaml --input '{...}'    # -> workflow ID
moco status <workflow-id>
moco history <workflow-id>                     # full execution event history
moco cancel <workflow-id>                      # graceful — cleanup runs
moco terminate <workflow-id> -r "reason"       # forceful — no cleanup
```

`start` defaults to `-t 300`. Prefer `cancel` over `terminate` unless the workflow is wedged.

## `moco validate` and `moco test`

```bash
moco validate flow.wfspec.yaml                 # local, offline, no auth
moco test                                      # tests/**/*.test.yaml in cwd
moco test tests/one.test.yaml --in-memory --verbose
```

Both are covered in depth by `moco-validating-workflows` and `moco-testing-workflows`.

## `moco activity` — one activity, no workflow

```bash
moco activity run http.request -i @input.json
moco activity run k8s.get -i '{"kind":"Pod","name":"x"}' --in-memory
moco activity start claude_agent.query -i @q.json   # -> activity ID
moco activity result <activity-id>
moco activity cancel <activity-id>
moco activity terminate <activity-id> -r "reason"
```

`-i/--input` and `-c/--config` accept inline JSON or `@file`. Also `--retry-policy <json|@file>`,
`--activity-id`, `--tier`, `-t/--timeout`, `-o/--output`.

This is the fastest way to learn an unfamiliar activity's real behaviour. Sample payloads live in
`moco-examples/activity-examples/sample_inputs/`.

## Publishing

```bash
moco publish                       # current dir; needs moco.json
moco publish ./my-project --dry-run
moco publish --namespace <id>
```

Validates the project config and discovered sources, then publishes the package to a namespace.
Always `--dry-run` first.

## State and secrets

```bash
moco state upload data.json --namespace uploads --key seed
moco secret list
moco secret upload MY_TOKEN "value"      # encrypted client-side
moco secret delete MY_TOKEN --force
```

Add `--global` to operate on global rather than namespace-scoped secrets. Never inline a secret in
a wfspec — read it with the `builtin.secret.get` activity.

## Session, schema, config, auth

```bash
moco login                         # OAuth2 PKCE; opens a browser
moco logout --all                  # also clears the stored API key
moco session show
moco session select <namespace-id>
moco schema update                 # refresh the cached wfspec schema
moco schema show                   # which schema is active, and its hash
moco config list
moco config set <key> <value>
moco apikey create <name> --save   # long-lived credential for CI
```

Auth precedence: `--auth` → `MOCO_API_KEY` → `~/.moco/credentials.json` → OAuth → unauthenticated.

## Notes

- `--debug` and `--auth <mode>` exist on nearly every remote command.
- First `moco run` against a server may open a browser for OAuth — wait for the user to finish.
- If a command cannot reach the server at all, that is an infra problem. Surface it rather than
  retrying in a loop.
