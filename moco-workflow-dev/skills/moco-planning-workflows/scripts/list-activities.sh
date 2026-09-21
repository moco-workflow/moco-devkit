#!/usr/bin/env bash
# Inspect the Moco activity catalog without loading the whole wfspec JSON schema into context.
#
# The schema is the authoritative inventory: $defs.ActivityType.enum lists every activity type
# the engine accepts, and $defs["activity_input.<type>"] is that activity's input schema. Reading
# it here rather than recalling it is the difference between a grounded feasibility verdict and a
# hallucinated activity type.
#
# Usage:
#   list-activities.sh                      # families + counts (start here)
#   list-activities.sh --all                # every activity type
#   list-activities.sh --family builtin     # types in one family
#   list-activities.sh --grep email         # search types by substring
#   list-activities.sh --schema http.request  # one activity's input schema
#   list-activities.sh --exists k8s.apply   # exit 0 if the type is real, 1 if not
#
# Override schema discovery with MOCO_WFSPEC_SCHEMA=/path/to/workflowspec_schema.json

set -euo pipefail

find_schema() {
  if [[ -n "${MOCO_WFSPEC_SCHEMA:-}" ]]; then
    printf '%s\n' "$MOCO_WFSPEC_SCHEMA"
    return
  fi
  local here candidates=()
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Shipped alongside this plugin (the normal case).
  candidates+=("${CLAUDE_PLUGIN_ROOT:-$here/../../..}/skills/moco-developing-workflows/workflowspec_schema.json")
  candidates+=("$here/../../moco-developing-workflows/workflowspec_schema.json")
  # Working inside the moco repo.
  candidates+=("${CLAUDE_PROJECT_DIR:-.}/scripts/schema_gen/schemas/workflowspec_schema.json")
  # Whatever `moco schema update` last downloaded.
  candidates+=("$HOME/.moco/schemas/workflowspec_schema.json")
  local c
  for c in "${candidates[@]}"; do
    [[ -f "$c" ]] && { printf '%s\n' "$c"; return; }
  done
  echo "error: no workflowspec_schema.json found. Set MOCO_WFSPEC_SCHEMA, or run 'moco schema update'." >&2
  exit 2
}

SCHEMA="$(find_schema)"
MODE="${1:---families}"
ARG="${2:-}"

python3 - "$SCHEMA" "$MODE" "$ARG" <<'PY'
import json, sys, collections

schema_path, mode, arg = sys.argv[1], sys.argv[2], sys.argv[3]
with open(schema_path, encoding="utf-8") as fh:
    schema = json.load(fh)

defs = schema.get("$defs", {})
types = defs.get("ActivityType", {}).get("enum")
if not types:
    sys.exit("error: ActivityType enum not found in %s" % schema_path)
types = sorted(types)

def families():
    counts = collections.Counter(t.split(".")[0] for t in types)
    print("%d activity types in %d families  (%s)\n" % (len(types), len(counts), schema_path))
    width = max(len(f) for f in counts)
    for fam, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        sample = [t for t in types if t.startswith(fam + ".")][:3]
        more = "" if n <= 3 else ", ..."
        print("  %-*s %3d   %s%s" % (width, fam, n, ", ".join(sample), more))
    print("\nNo native activity for what you need? Do NOT conclude 'infeasible' yet —")
    print("try mcp.call_tool (any MCP tool), then http.request (any REST API), then shell.run.")

if mode in ("--families", "-f", ""):
    families()
elif mode == "--all":
    print("\n".join(types))
elif mode == "--family":
    hits = [t for t in types if t.startswith(arg + ".")]
    print("\n".join(hits) if hits else "no family %r (run --families)" % arg)
elif mode == "--grep":
    hits = [t for t in types if arg.lower() in t.lower()]
    print("\n".join(hits) if hits else "no activity type matching %r" % arg)
elif mode == "--exists":
    if arg in types:
        print("%s  EXISTS" % arg)
    else:
        near = [t for t in types if arg.split(".")[0] == t.split(".")[0]][:8]
        print("%s  DOES NOT EXIST — do not use it." % arg)
        if near:
            print("same family: %s" % ", ".join(near))
        sys.exit(1)
elif mode == "--schema":
    if arg not in types:
        sys.exit("%s is not a real activity type (run --grep to search)" % arg)
    body = defs.get("activity_input.%s" % arg)
    if body is None:
        print("%s takes no declared input schema." % arg)
    else:
        print(json.dumps(body, indent=2))
else:
    sys.exit("unknown mode %r — see the header of this script for usage" % mode)
PY
