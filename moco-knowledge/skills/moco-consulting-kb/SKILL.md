---
name: moco-consulting-kb
description: "Consults the Moco workflow knowledge base — authoring rules, reusable blocks, and the catalog of existing examples — and captures what was learned afterwards. Use when: (1) about to build or change a Moco workflow, (2) looking for the nearest existing example to copy, (3) checking a spec against the authoring rules, (4) asking how a Moco pattern is normally done, or (5) finishing a workflow and wanting the learnings kept."
---

# Consulting the Moco knowledge base

Two jobs, at opposite ends of the work: **read the KB before building**, and **dump what you
learned after**. Both matter — the second is what makes the first better next time.

The KB lives at `${CLAUDE_PLUGIN_ROOT}/knowledge/`:

```
knowledge/rules.yaml           must / should / retired — one line each, with a mechanical check
knowledge/blocks/*.md          16 reusable building pieces — the source of truth
knowledge/examples-index.yaml  every example under moco-examples/ — the match target
```

---

## Before building

**1. Read the rules.** `knowledge/rules.yaml`, in full. It is short by design. Do not paraphrase
it from memory — the whole point is that it changes as the KB learns.

**2. Find the nearest existing example.** Match the request against the `description` field in
`knowledge/examples-index.yaml`. That field says what each workflow *is*, which is what you are
matching on — there is no taxonomy to classify into.

Prefer entries flagged `good_starting_point`. Read the entry's `note` before copying: it says
what to know in advance. Then open the real `spec` and use it as the structural template.

**Never start from a blank canvas.** Copying a working spec and adapting it beats writing from
scratch, every time.

**3. Read the blocks that apply.** From the matched example's `blocks:` list, plus any the request
obviously needs. Each block names the rules it `follows:` and the blocks it `pairs_with:`, so one
block leads to the others you need.

Treat a block's **`## Watch out`** as the highest-value part. That is where the failure modes
live — the things that are not obvious from the snippet and cost someone real time to discover.

**4. Note the caveats.** `blocks_verified: false` on an index entry means the block list was
derived mechanically and never confirmed — a hint, not a fact. A rule with empty `seen_in:` and
only a `source:` is repo policy rather than something observed in a spec.

---

## After building

Append what you learned to **`${CLAUDE_PLUGIN_DATA}/learnings.md`** (create it if absent).

**Dump freely.** Raw, repetitive and half-formed is fine and expected — capturing is cheap, and
you should not be editing the shared KB mid-task. The `moco-knowledge-curator` agent decides
later what earns a place. Record only what you discovered *this time* that is not already in
`knowledge/`.

Mirror the KB's own structure so the curator can route each item without guessing:

```markdown
## --- <workflow-name> (<YYYY-MM-DD>) ---

### Rules (→ rules.yaml)
- <a build rule you learned the hard way; note must vs should if you can, and how to check it>

### Blocks (→ blocks/)
- <a reusable piece, or a gotcha to add to an existing block's "## Watch out">

### Activity gotchas
- <a runtime surprise from an activity: an input that is not what the schema implies, a
  timeout that is not what you expected, an output shape that differs from the docs>

### Examples (→ examples-index.yaml)
- name: <workflow name>
  dir: <dir under moco-examples/>
  spec: <path to the main spec>
  description: <one line: what this workflow does>
  blocks: [<block ids it is built from>]
  tests: <count>
```

If nothing new was learned, still add the Examples entry — a new workflow in the corpus is itself
knowledge, and the catalog is the thing everyone else matches against.

Then tell the user:

```
Learnings appended to ${CLAUDE_PLUGIN_DATA}/learnings.md.
To fold them into the shared KB, run the moco-knowledge-curator agent.
```

---

## Do not

- Edit `knowledge/` directly while building. Capturing and curating are separate jobs, and the
  separation is what keeps the KB from sprawling. Dump to learnings; let the curator fold.
- Promote your own learning into a rule because it feels important. `seen_in` is the gate, and
  one sighting is a guess.
- Skip the dump because the workflow "went fine". A clean build still tells the catalog a new
  example exists.
