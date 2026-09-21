# The Moco workflow knowledge base

A knowledge base that answers one question — **"how is a Moco workflow built?"** — and gets
better every time someone builds one.

---

## The idea in one line

**Blocks are the source of truth. Everything else points at them.**

## What is in here

```
knowledge/
├── blocks/             the reusable pieces a workflow is built from — the source of truth
├── rules.yaml          what to follow: must (hard) and should (guidance)
├── examples-index.yaml every workflow example: description, blocks, spec — the match target
└── README.md           this file
```

### `blocks/` — the pieces

One file per reusable building piece. 16 of them, covering durable state, state machines, entity
workflows, cross-workflow events, parallel fan-out, child workflows, functions, aborts,
continue-as-new, the rules engine, async activities, external system lifecycles, AI activities,
imports, and debug tracing.

Each block states, in plain fields: **what** it does and **use_when** to reach for it, its
**inputs**/**outputs**, which **rules** it **follows**, what it **pairs_with**, where it comes
**from** (the real statement or activity — we point at it, never copy it), and **seen_in**: the
real examples that use it, which is what tells us it is worth keeping.

Then a `## Snippet` and a `## Watch out`. **The how and the why live in `## Watch out`** — that is
what keeps the rules one line each.

### `rules.yaml` — what to follow

Split into **must** (breaking one is a bug the reviewer blocks on) and **should** (guidance the
reviewer flags but does not block). Each rule is one line plus a mechanical `check:` and its
evidence.

Evidence is either `seen_in:` (observed in real specs — the strongest kind) or `source:` (stated
repo policy, or a fact read off the wfspec schema). **A rule with neither is not a rule yet** and
belongs in learnings until it earns evidence.

Wrong rules are moved to **`retired`** with a reason rather than deleted, so they cannot quietly
creep back in a later curation run.

### `examples-index.yaml` — the catalog

One entry per example under `moco-examples/`: a one-line `description`, the `blocks` it is built
from, and the `dir`/`spec` it lives in. No copies.

This is the match target — "find the nearest thing to X" is a lookup over what actually exists,
which is why there is deliberately **no archetype taxonomy** layered on top: a taxonomy drifts
from reality and forces bad fits. The cleanest examples are flagged `good_starting_point`.

`blocks_verified: false` means the block list was derived mechanically and has not been confirmed
against the spec. Treat it as a hint; the curator clears these over time.

---

## How it stays sharp

Capturing a learning and folding it into the KB are **two different jobs**:

```
build a workflow  →  ${CLAUDE_PLUGIN_DATA}/learnings.md  →  curator folds in  →  branch
   (dump freely)       (raw, messy, outside any repo)      (merge/promote/retire)  (you review)
```

Dumping is cheap and deliberately unfiltered — the builder should not be editing a shared KB
mid-task. The **`moco-knowledge-curator`** agent is the fold-in step: it merges duplicates,
promotes repeated learnings, retires obsolete rules, reconciles the catalog, and writes a
changelog.

Two rules make this work:

- **`seen_in` is the promotion gate.** Seen once is a guess and stays in learnings. Seen across
  several specs earns a place.
- **Never hard-delete.** Retire with a reason.

The measure of success: the KB covers **more** over time while the number of entries stays
**flat**. If it is just getting longer, curation is not happening.

## Keeping references resolving

Every block's `follows:` must name a real rule id; every `blocks:` entry in the index must name a
real block; every `dir`/`spec` must exist on disk. Check it:

```bash
scripts/reconcile-examples-index.sh moco-examples
```

The curator runs this on **every** run — not only for what it is curating — so the catalog
converges on its own rather than depending on each author to come back and register their work.

## A note on where this came from

`moco-examples/AGENTS.md` already sketched this idea: extract lessons into `LESSONS.md`,
consolidate repeated ones upward, and eventually fold them into a skill. That ladder was right;
it just had no owner, no gate, and no destination, so the `## lessons` section stayed empty. This
KB is that ladder with all three.
