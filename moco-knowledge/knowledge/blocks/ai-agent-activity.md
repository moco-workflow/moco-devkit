---
id: ai-agent-activity
what: Calling an LLM, an agent loop, or a retrieval index from a workflow.
use_when: A step needs generation, classification, extraction, or retrieval over documents.
inputs:
  - {name: prompt, type: str}
outputs:
  - {name: completion, type: any}
follows: [no-inline-secrets, output-data-is-none-safe]
pairs_with: [parallel-fan-out, rules-engine, namespace-state-store]
from: "openai.chat.completions / claude_agent.query / llama_index.*"
seen_in: [openai-demo, claude-agent-demo, ai-agent-demo, rag-demo, sre-incident-agent, contract-intelligence-agent, moco-agent]
status: active
---

# AI and agent activities

| Need | Activity |
|---|---|
| One LLM call | `openai.chat.completions` |
| A multi-turn agent loop with tools | `claude_agent.query` |
| RAG | `llama_index.index_*` then `llama_index.query` |
| Scoring and evaluation | `langfuse.create_score`, `langfuse.run_experiment` |

## Snippet

Fan out specialised agents and aggregate:

```yaml
iteration:
  iter_type: parallel
  join_type: and
  input_data: "{{subtopics}}"
  body:
    activity:
      type: openai.chat.completions
      name: research-one
      input_data:
        messages:
          - {role: user, content: "Research: {{iter_item}}"}
  output_name: findings
```

## Watch out

- **`claude_agent.query` runs on the dedicated `agent` worker**, not the base worker, and a single
  call can run for a long time. Budget `timeout_sec` accordingly; do not treat it like an HTTP
  call.
- Model output is untrusted and unstructured. Never feed it straight into a comparison or index
  it without a guard — this is the most common source of eager-evaluation `NoneType` failures
  (rule `output-data-is-none-safe`).
- Never inline an API key (rule `no-inline-secrets`) — use `builtin.secret.get`.
- Fanning out agents in parallel multiplies cost and rate-limit pressure as well as speed. Bound
  the fan-out.
- For RAG, indexing and querying are separate activities with different lifetimes. Index once and
  reuse; do not re-index per request.
- No native activity for a provider does not mean it is unreachable — `openai-demo` calls Gemini
  over `http.request`, which is the worked example of the escape hatch.
