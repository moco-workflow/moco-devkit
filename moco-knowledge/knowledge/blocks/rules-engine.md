---
id: rules-engine
what: Declarative fact inference — rules that fire on conditions and assert new facts or actions.
use_when: Business logic is a set of independent policies rather than a sequence, or non-engineers need to read it.
inputs:
  - {name: facts, type: dict}
  - {name: run_mode, type: str}
  - {name: rules, type: list}
outputs:
  - {name: derived facts, type: dict}
follows: [comment-freely, test-the-boundary]
pairs_with: [parallel-fan-out, ai-agent-activity]
from: rules_engine
seen_in: [moco-workflow-demo, rules-engine-demo, contract-intelligence-agent]
status: active
---

# Rules engine

## Snippet

```yaml
rules_engine:
  input_data:
    facts:
      applicant: {age: 25, income: 90000, score: 710}
    run_mode: forward           # forward | backward
  rules:
    - id: is-adult
      if:
        expression: "{{applicant.age >= 18}}"
      then:
        set_facts:
          - applicant.is_adult: true

    - id: approve
      if:
        with_facts: [applicant.is_adult]
        expression: "{{applicant.score >= 700}}"
      then:
        set_facts:
          - decision: approved
  output_name: derived
```

**forward** chains from the facts you have toward whatever can be derived. **backward** starts
from a goal and works out what would have to be true.

## Watch out

- Rules fire on facts, not in file order. If a rule depends on another's output, say so with
  `with_facts` — do not rely on ordering.
- A rule asserting a fact another rule's condition reads can loop. Keep the derivation acyclic.
- Unmatched facts are silent. A rule that never fires looks identical to a rule that fired and
  changed nothing, so test each rule's condition at its boundary.
- Good for aggregating independent findings — `contract-intelligence-agent` uses it to combine
  four child agents' outputs into one risk decision, which reads far better than nested
  conditionals.
- Start from `moco-examples/moco-workflow-demo/src/rules-engine-basics-demo.yaml`; the
  `rules-engine-demo` version adds an audit trail and is a bigger first read.
