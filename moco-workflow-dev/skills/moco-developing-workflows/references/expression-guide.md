# Expression guide

Moco evaluates Python expressions inside `{{ }}`, in a sandbox, during execution.

## The one rule

**Every expression is wrapped in `{{ }}`.** A bare Python-looking string is a literal string, and
it fails silently — it produces the text `sorted(items)` rather than a sorted list.

```yaml
- sorted_items#: "{{sorted(items)}}"     # correct
- sorted_items#: "sorted(items)"         # WRONG — the literal string "sorted(items)"
```

## The three value forms

```yaml
# 1. Expression — evaluated as Python
- total#: "{{sum(amounts)}}"

# 2. Template string — interpolate into surrounding text
- message#: "Hello {{name}}, you have {{len(items)}} items"
- url#: "https://api.example.com/users/{{user_id}}"

# 3. Literal — no braces, no evaluation
- status#: pending
- count#: 42
```

Multi-line expressions use a YAML block scalar:

```yaml
- payload#: |
    {{
      {
        'name': user_name,
        'items': item_list,
        'total': sum(prices),
      }
    }}
```

A dict literal needs its own braces *inside* the expression braces — three layers total:

```yaml
- doubled#: "{{ {k: v * 2 for k, v in scores.items()} }}"
```

## Variable-name modifiers

Syntax: `name[@][#modifier][#]`

| Modifier | Effect | Example |
|---|---|---|
| `#` trailing | Log the evaluated value to the CLI | `result#: "{{x}}"` |
| `@` | Container scope — local to the enclosing composite | `temp@: "{{x}}"` |
| `#literal` | Do not evaluate | `tmpl#literal: "{{raw}}"` |
| `#jinja` | Render as a Jinja2 template | `body#jinja: "..."` |
| `#python` | Force Python evaluation | `v#python: "{{x}}"` |
| `#python_glom` | Evaluate as a glom path | `p#python_glom: "a.b.c"` |

They combine: `temp@#: "{{expensive()}}"` is container-scoped *and* logged.

There is no `log#` keyword — logging is just a variable whose name ends in `#`:

```yaml
- log#: "Processing {{name}}"     # logged; nothing downstream needs to read it
```

## Available inside expressions

**Builtins:** `abs`, `all`, `any`, `bool`, `dict`, `enumerate`, `filter`, `float`, `int`,
`isinstance`, `len`, `list`, `map`, `max`, `min`, `range`, `round`, `set`, `sorted`, `str`, `sum`,
`tuple`, `zip`

**Libraries:** `np` (numpy), `pd` (pandas), `pa` (pyarrow), `glom`, `jinja2`

Use `isinstance(x, str)` for type checks — the sandbox is deliberately narrow, so assume anything
not listed above is unavailable until proven otherwise.

## Patterns

```yaml
# Comprehensions
- active#: "{{[u for u in users if u['active']]}}"
- names#: "{{[u['name'].upper() for u in users]}}"
- by_id#: "{{ {u['id']: u for u in users} }}"

# Safe access — output_data is evaluated eagerly, so guard anything nullable
- city#: "{{addr.get('city', 'unknown')}}"
- amount#: "{{(order.get('amount') or 0) * 1.1}}"
- ok#: "{{value is not None and value > 0}}"

# Conditionals
- tier#: "{{'gold' if spend > 1000 else 'standard'}}"

# Strings
- greeting#: "{{f'Hello {name}!'}}"
- slug#: "{{title.lower().replace(' ', '-')}}"

# Aggregation
- avg#: "{{sum(v) / len(v) if v else 0}}"
- top#: "{{sorted(items, key=lambda i: i['score'], reverse=True)[:5]}}"

# Pandas, for bulk tabular work
- adults#: "{{df[df['age'] >= 18]}}"
- mean_age#: "{{df['age'].mean()}}"
```

## Traps

**`output_data` evaluates every entry, eagerly.** There is no short-circuiting because a later
step might not need a value — so any expression touching a nullable value must be None-safe
(`(x or 0)`, or an `is not None` guard). This is the most common runtime failure.

**Division by zero on empty collections** — `sum(v) / len(v)` raises when `v` is empty. Guard it.

**`iter_item` is the item itself** — `iter_item['field']`, never `iter_item['value']['field']`.

**`timeout_sec` must be a number literal** — `timeout_sec: "{{t}}"` is invalid.

**Keep expressions cheap.** A deeply nested comprehension over large collections can be slow;
hoist loop-invariant sub-expressions into `input_data` rather than rebuilding them per iteration.

## Debugging

Append `#` to any variable name to stream its value to the CLI:

```yaml
- _debug_orders#: "{{orders[:3]}}"
```

Running a **local file**, traces print automatically. Running a **deployed workflow by name**,
pass `--debug`. Traces from child workflows are collected too.
