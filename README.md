# moco-devkit

Claude Code plugins for building Moco workflows.

Two plugins. **`moco-workflow-dev`** is the pipeline — plan, build, validate, test, run.
**`moco-knowledge`** is the memory — a knowledge base plus the curation loop that keeps it sharp.
Install either on its own; they work better together but neither depends on the other.

## Install

From inside Claude Code, with this repo checked out:

```
/plugin marketplace add /path/to/moco
/plugin install moco-workflow-dev@moco-devkit
/plugin install moco-knowledge@moco-devkit
```

Or point at the remote:

```
/plugin marketplace add <git-url-of-this-repo>
```

Then `/reload-plugins`.

### Update, remove, inspect

```
/plugin marketplace update moco-devkit
/plugin update moco-workflow-dev@moco-devkit
/plugin uninstall moco-knowledge
/plugin list
```

```bash
claude plugin validate ./moco-devkit/moco-workflow-dev
claude plugin details moco-workflow-dev        # components and token cost
```

## `moco-workflow-dev`

| Skill | What it does |
|---|---|
| `moco-planning-workflows` | Analyses a request, checks it against the **real** activity catalog, returns a feasibility verdict and a build plan |
| `moco-developing-workflows` | wfspec syntax — statements, expressions, data flow, patterns |
| `moco-testing-workflows` | Unit and integration tests, mocking, the four expectation types |
| `moco-validating-workflows` | The validate → run → test → review fix loop, with error classification |
| `moco-executing-workflows` | The `moco` CLI surface |

The pipeline is **plan → develop → validate → test → execute**. Planning first is the point:
it is the step that catches "this needs an activity that does not exist" and "this was never a
workflow problem" before any YAML gets written.

Feasibility is grounded, not recalled. `moco-planning-workflows/scripts/list-activities.sh` reads
the activity catalog straight out of the shipped wfspec JSON schema:

```bash
list-activities.sh                       # 182 types across 19 families
list-activities.sh --grep slack          # search
list-activities.sh --exists k8s.apply    # is it real? exit 1 if not
list-activities.sh --schema http.request # what inputs does it take?
```

## `moco-knowledge`

| Component | What it does |
|---|---|
| `moco-consulting-kb` (skill) | Read the KB before building; dump what you learned after |
| `moco-knowledge-curator` (agent) | Folds raw learnings into the KB, reconciles the catalog, commits to a review branch |
| `moco-workflow-reviewer` (agent) | Adversarially checks a spec against the rules; PASS/FAIL with evidence |
| `knowledge/` | 16 blocks, 31 rules, 23 catalogued examples |

### The memory loop

This is the part worth understanding. Capturing knowledge and curating it are **two different
jobs**, and conflating them is why most knowledge bases rot:

```
build a workflow  →  ${CLAUDE_PLUGIN_DATA}/learnings.md  →  curator folds in  →  branch
   (dump freely)       (raw, messy, outside any repo)      (merge/promote/retire)  (you review)
```

The builder dumps freely — unfiltered, duplicative, cheap. The curator later decides what earns a
place, under two rules:

- **`seen_in` is the promotion gate.** Seen in one workflow is a guess and stays in learnings.
  Seen across several earns a rule or a block.
- **Nothing is ever hard-deleted.** Wrong entries move to `retired` with a reason, so they cannot
  creep back in a later run.

Success is the KB covering **more** over time while entry count stays **flat**. If it is only
getting longer, curation is not happening.

The curator also **reconciles the example catalog on every run**, not just for what it is
curating — so the catalog converges on its own instead of depending on each author to remember to
register their work:

```bash
moco-knowledge/scripts/reconcile-examples-index.sh moco-examples
```

That script is also the KB's integrity check: it verifies every `dir`, `spec`, block reference,
and rule reference resolves. It exits non-zero on drift.

## Prepackaged into the agent worker

The devkit has a second life as the built-in plugin catalog of the `moco-agent` image.
`docker/Dockerfile.moco-agent` copies this directory to `/moco/plugins` and defaults
`MOCO_CLAUDE_AGENT_PLUGIN_ROOT` there, so a `claude_agent.query` activity can load these plugins
with no operator setup:

```yaml
capabilities:
  plugins:
    - moco-workflow-dev
  skills:
    - moco-workflow-dev:moco-developing-workflows
```

Baking is the only option, not a preference. Every agent run gets a fresh `HOME` and
`CLAUDE_CONFIG_DIR` that is deleted when the run ends, so `/plugin install` into the image would
be invisible at run time; and a ConfigMap volume is flat, so it cannot carry this tree. Absolute
paths handed to the SDK's `plugins=` option are the route.

Two things behave differently there than they do in Claude Code:

- **The memory loop does not close.** `${CLAUDE_PLUGIN_DATA}/learnings.md` lives on the per-run
  workspace and goes away with it, so in the worker the KB is read-only. Curation stays a
  developer-machine activity.
- **`reconcile-examples-index.sh` is inert** — it needs a `moco-examples` checkout and PyYAML,
  neither of which is in the image. `list-activities.sh` does work (it resolves the schema via
  `CLAUDE_PLUGIN_ROOT`), but needs the `Bash` tool, which is an elevated grant.

Selecting any plugin escalates the activity's authz action to `run_agent_elevated`, because plugin
hooks run shell commands outside the tool permission system. Operators can drop the built-ins
entirely with `agentWorker.pluginRoot.builtin=false`.

## Relationship to `moco-examples/.claude/skills/`

Those skills still exist and still work when you are inside `moco-examples/`. This devkit is
separate and self-contained, with distinct skill names, so both can be active without colliding.
Nothing under `moco-examples/.claude/` is modified by installing these plugins.

## Keeping the schema current

`moco-developing-workflows/workflowspec_schema.json` is generated. Regenerate it with the other
copies:

```bash
make gen-catalog && make gen-schema
```

`moco-testing-workflows/workflowspec_test_schema.json` is maintained by hand; copy it from
`scripts/schema_gen/schemas/` when it changes.
