#!/usr/bin/env bash
# Reconcile knowledge/examples-index.yaml against what is actually on disk, and check the
# KB's internal references resolve.
#
# The curator runs this on EVERY curation run, not just for the examples it happens to be
# curating — that is what makes the catalog converge on its own instead of depending on each
# author to come back and register their work.
#
# Usage:
#   reconcile-examples-index.sh [path/to/moco-examples]
#
# Exit codes: 0 = in sync, 1 = drift found (missing entries, dangling dirs, or broken refs).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KB="${CLAUDE_PLUGIN_ROOT:-$HERE/..}/knowledge"
[[ -d "$KB" ]] || KB="$HERE/../knowledge"

EXAMPLES="${1:-}"
if [[ -z "$EXAMPLES" ]]; then
  for c in "${CLAUDE_PROJECT_DIR:-.}/moco-examples" "$HERE/../../../moco-examples" "./moco-examples"; do
    [[ -d "$c" ]] && { EXAMPLES="$c"; break; }
  done
fi
if [[ ! -d "$EXAMPLES" ]]; then
  echo "error: moco-examples not found. Pass it as the first argument." >&2
  exit 2
fi

python3 - "$KB" "$EXAMPLES" <<'PY'
import os, sys, glob, re
try:
    import yaml
except ImportError:
    sys.exit("error: PyYAML is required (pip install pyyaml)")

kb, examples = sys.argv[1], os.path.normpath(sys.argv[2])
index_path = os.path.join(kb, "examples-index.yaml")
rules_path = os.path.join(kb, "rules.yaml")
blocks_dir = os.path.join(kb, "blocks")

with open(index_path, encoding="utf-8") as fh:
    index = yaml.safe_load(fh) or {}
entries = index.get("examples") or []

# --- what is actually on disk: a dir counts when it holds a spec ------------------
def has_spec(d):
    return bool(glob.glob(os.path.join(d, "src", "*.yaml"))
                or glob.glob(os.path.join(d, "*.yaml")))

on_disk = set()
for name in sorted(os.listdir(examples)):
    full = os.path.join(examples, name)
    if not os.path.isdir(full) or name.startswith("."):
        continue
    if has_spec(full):
        on_disk.add(name)
# root-level specs are catalogued with dir "."
if glob.glob(os.path.join(examples, "*.yaml")):
    on_disk.add(".")
# payload-only dirs still earn an entry if they are referenced as examples
for name in ("activity-examples",):
    if os.path.isdir(os.path.join(examples, name)):
        on_disk.add(name)

catalogued = {e.get("dir") for e in entries if e.get("dir")}
problems = 0

# --- 1. on disk but not catalogued -----------------------------------------------
missing = sorted(on_disk - catalogued)
print("== examples on disk with no index entry ==")
if missing:
    problems += len(missing)
    for m in missing:
        print("  ADD  %s" % m)
    print("\n  Add an entry for each, with blocks_verified: false, and report them")
    print("  as a table in the curation changelog.")
else:
    print("  none — catalog already current")

# --- 2. catalogued but not on disk -----------------------------------------------
dangling = sorted(d for d in catalogued if d not in on_disk
                  and not os.path.isdir(os.path.join(examples, d)) and d != ".")
print("\n== index entries whose dir does not resolve ==")
if dangling:
    problems += len(dangling)
    for d in dangling:
        print("  FIX  %s" % d)
else:
    print("  none")

# --- 3. spec: paths resolve -------------------------------------------------------
print("\n== index entries whose spec does not resolve ==")
bad_spec = []
for e in entries:
    spec = e.get("spec")
    if spec and not os.path.isfile(os.path.join(examples, spec)):
        bad_spec.append((e.get("name"), spec))
if bad_spec:
    problems += len(bad_spec)
    for n, s in bad_spec:
        print("  FIX  %-28s %s" % (n, s))
else:
    print("  none")

# --- 4. every block referenced by the index exists --------------------------------
known_blocks = {os.path.splitext(os.path.basename(p))[0]
                for p in glob.glob(os.path.join(blocks_dir, "*.md"))}
print("\n== index entries referencing a block that does not exist ==")
bad_blocks = []
for e in entries:
    for b in e.get("blocks") or []:
        if b not in known_blocks:
            bad_blocks.append((e.get("name"), b))
if bad_blocks:
    problems += len(bad_blocks)
    for n, b in bad_blocks:
        print("  FIX  %-28s %s" % (n, b))
else:
    print("  none")

# --- 5. every rule id a block `follows:` exists ------------------------------------
with open(rules_path, encoding="utf-8") as fh:
    rules = yaml.safe_load(fh) or {}
rule_ids = {r["id"] for tier in ("must", "should", "retired")
            for r in (rules.get(tier) or []) if isinstance(r, dict) and "id" in r}

print("\n== blocks whose `follows:` names a rule that does not exist ==")
bad_follows = []
block_slugs = set()
for path in sorted(glob.glob(os.path.join(blocks_dir, "*.md"))):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        continue
    fm = yaml.safe_load(m.group(1)) or {}
    slug = os.path.splitext(os.path.basename(path))[0]
    block_slugs.add(slug)
    if fm.get("id") and fm["id"] != slug:
        problems += 1
        print("  FIX  %s: frontmatter id %r != filename" % (slug, fm["id"]))
    for r in fm.get("follows") or []:
        if r not in rule_ids:
            bad_follows.append((slug, r))
if bad_follows:
    problems += len(bad_follows)
    for s, r in bad_follows:
        print("  FIX  %-28s %s" % (s, r))
else:
    print("  none")

# --- 6. blocks nothing points at ---------------------------------------------------
used = {b for e in entries for b in (e.get("blocks") or [])}
orphans = sorted(block_slugs - used)
print("\n== blocks no example claims to use ==")
print("  " + (", ".join(orphans) if orphans else "none"))
if orphans:
    print("  (not an error — but a block with no example is a block nobody has confirmed)")

# --- summary -----------------------------------------------------------------------
unverified = sum(1 for e in entries if e.get("blocks_verified") is False)
print("\n-- %d examples catalogued, %d on disk, %d with blocks_verified: false"
      % (len(entries), len(on_disk), unverified))
print("-- %d blocks, %d rules" % (len(block_slugs), len(rule_ids)))
if unverified:
    print("-- confirm one or two unverified block lists this run, then drop the flag")
print("-- %s" % ("IN SYNC" if problems == 0 else "%d problem(s) found" % problems))
sys.exit(1 if problems else 0)
PY
