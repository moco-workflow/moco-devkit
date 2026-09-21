# Workflow Test Schema Quick Reference

Quick reference for the workflow test file schema. The skill itself is [../SKILL.md](../SKILL.md).

## Schema Location

JSON Schema: `../workflowspec_test_schema.json`

## Test Suite Types

### Integration Test Suite

Tests complete workflow execution end-to-end.

```yaml
test_type: integration-test

wfspec:
  name: string              # Required
  version: string           # Optional
  content: string[]         # Optional: inline workflow YAML

test_cases:                 # Required
  - id: string              # Required
    input: object|object[]  # Required
    expect: object          # Required
    mocks: object[]         # Optional
    skip: boolean           # Optional
    verbose: boolean        # Optional

test_data: object           # Optional
skip: boolean               # Optional
verbose: boolean            # Optional
```

### Unit Test Suite

Tests individual named steps in isolation.

```yaml
test_type: unit-test

wfspec:
  name: string              # Required
  version: string           # Optional
  content: string[]         # Required: inline workflow YAML

test_groups:                # Required
  - step_name: string       # Required
    test_cases:             # Required (same as integration)
      - id: string
        input: object|object[]
        expect: object
        mocks: object[]
        skip: boolean
        verbose: boolean
    skip: boolean           # Optional
    verbose: boolean        # Optional

test_data: object           # Optional
skip: boolean               # Optional
verbose: boolean            # Optional
```

## Test Case Structure

```yaml
id: string                  # Required: unique test identifier

input: object | object[]    # Required: test input data

expect:                     # Required: test expectations
  output:                   # Optional: validate output variables
    - var1: value1
      var2: value2
    - var3: "{{ expression }}"

  terminate:                # Optional: expect termination
    terminate_message: string | null

  error:                    # Optional: expect error
    error_type: string | null
    error_message: string | null

  assert:                   # Optional: custom assertions
    - "{{ expression }}"
    - "{{ expression }}"

mocks:                      # Optional: activity mocks
  - wfspec_name: string     # Optional
    step_name: string       # Required
    _raw_output: any        # Required

skip: boolean               # Optional: skip this test
verbose: boolean            # Optional: enable verbose output
```

## Expectation Types

### Output Validation

```yaml
expect:
  output:
    - variable_name: expected_value
    - another_var: "{{ expression }}"
```

**Behavior**: Checks that output variables match expected values.
**Match**: All specified variables must match.

### Termination Validation

```yaml
expect:
  terminate:
    terminate_message: "expected message"
    # or
    terminate_message: null  # Any termination
```

**Behavior**: Checks that workflow terminated early (via abort).
**Match**: Must terminate; message must match if specified.

### Error Validation

```yaml
expect:
  error:
    error_type: "ErrorClassName"
    error_message: "expected message"
    # Fields can be null to match any value
```

**Behavior**: Checks that workflow failed with expected error.
**Match**: Must fail; type and message must match if specified.

### Custom Assertions

```yaml
expect:
  assert:
    - "{{ len(result) > 0 }}"
    - "{{ status == 'success' }}"
```

**Behavior**: Evaluates Python expressions against output.
**Match**: All assertions must evaluate to `True`.

## Mock Structure

```yaml
mocks:
  - wfspec_name: workflow-name    # Optional: defaults to current workflow
    step_name: step-to-mock       # Required: step name with activity/workflow
    _raw_output:                  # Required: mocked output
      key: "value"
      status: "success"
```

**Behavior**: When the specified step executes, returns `_raw_output` immediately without executing the actual activity/workflow.

## Complete Minimal Examples

### Minimal Integration Test

```yaml
test_type: integration-test
wfspec:
  name: my-workflow
test_cases:
  - id: test-1
    input:
      param: "value"
    expect:
      output:
        - result: "expected"
```

### Minimal Unit Test

```yaml
test_type: unit-test
wfspec:
  name: my-workflow
  content: |
    wfspec_name: my-workflow
    wfspec_version: 1.0.0
    body:
      transform:
        name: my-step
        output_data:
          - result: "{{ input_value }}"
test_groups:
  - step_name: my-step
    test_cases:
      - id: test-1
        input:
          input_value: "test"
        expect:
          output:
            - result: "test"
```

## Common Patterns

### Test with Multiple Expectations

```yaml
- id: comprehensive-test
  input:
    data: "test"
  expect:
    output:
      - status: "processed"
    assert:
      - "{{ len(items) > 0 }}"
      - "{{ total > 100 }}"
```

### Test with Mock and Error

```yaml
- id: api-failure-test
  input:
    user_id: "123"
  mocks:
    - step_name: call-external-api
      _raw_output:
        error: "API unavailable"
  expect:
    error:
      error_type: "APIError"
      error_message: "Failed to fetch user data"
```

### Test Group with Skip

```yaml
test_groups:
  - step_name: experimental-feature
    skip: true  # Skip all tests in this group
    test_cases:
      - id: test-1
        input: { ... }
        expect: { ... }
```

### Verbose Debugging

```yaml
test_cases:
  - id: debug-failing-test
    verbose: true  # Include test workflow YAML and full output
    input:
      data: "test"
    expect:
      output:
        - result: "expected"
```

## Validation Rules

### Required Fields

- **All tests**: `test_type`, `wfspec`, `wfspec.name`
- **Integration**: `test_cases`
- **Unit**: `test_groups`, `wfspec.content`
- **Test case**: `id`, `input`, `expect`
- **Mock**: `step_name`, `_raw_output`

### Constraints

- `test_type` must be `"integration-test"` or `"unit-test"`
- Test case `id` should be unique within a suite
- Unit test `step_name` must match a named step in the workflow
- Expectation objects can be empty `{}` (just checks no error)
- At least one expectation type should be specified in `expect`

## Schema Definitions

### WfspecInfo

```yaml
name: string               # Required
version: string            # Optional
content: string[]          # Optional (required for unit tests)
```

### ExpectTerminate

```yaml
terminate_message: string | null   # Required (null = any message)
```

### ExpectError

```yaml
error_type: string | null          # Required (null = any type)
error_message: string | null       # Required (null = any message)
```

## Tips

1. **Use descriptive IDs**: `greet-empty-name` is better than `test-1`
2. **Test one thing per case**: Easier to debug when tests fail
3. **Mock external dependencies**: Tests run faster and more reliably
4. **Use assertions for complex checks**: More flexible than output matching
5. **Enable verbose selectively**: Only for tests that are failing
6. **Skip don't delete**: Mark work-in-progress tests with `skip: true`
7. **Group related unit tests**: One test group per step or feature

## Related Files

- **JSON Schema**: [../workflowspec_test_schema.json](../workflowspec_test_schema.json)
- **System workflows**:
  - `sys.run_test.integration` - Integration test runner
  - `sys.run_test.unit` - Unit test runner
  - `sys.run_test.validate_test_case_expect` - Expectation validator
  - `sys.run_test.format_test_output` - HTML report generator
