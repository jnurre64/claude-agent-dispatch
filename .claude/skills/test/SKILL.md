---
name: test
description: Use when running tests, verifying code changes, or before commits/PRs in this repository. Checks prerequisites, runs ShellCheck and BATS, categorizes results.
user-invocable: true
---

# Test: Run ShellCheck and BATS with Prerequisite Detection

Run the project test suite with prerequisite checking and platform-aware result interpretation.

## Step 1: Check Prerequisites

Run the prerequisite detection script:

```bash
bash ${CLAUDE_SKILL_DIR}/../../../scripts/check-test-prereqs.sh
```

If any tools are missing:
- Show the user what's missing and the install commands from the script output
- Ask if they want you to run the install commands or if they'll do it manually
- Do NOT proceed to Steps 2-3 until prerequisites pass

## Step 2: Run ShellCheck

Run ShellCheck on all shell scripts:

```bash
shellcheck scripts/*.sh scripts/lib/*.sh
```

**Windows CRLF fallback:** If you see SC1017 errors ("Expected a function name but found end of line"), the files have CRLF line endings. Fix by running:

```bash
git add --renormalize . && git checkout -- .
```

Then re-run shellcheck.

## Step 3: Run BATS Tests

Run the full test suite:

```bash
./tests/bats/bin/bats tests/
```

## Step 4: Interpret Results

Categorize every failure as either a **known platform limitation** or a **real failure**.

### Known platform limitations (not real failures)

| Platform | Issue | Affected Tests | Why |
|----------|-------|---------------|-----|
| Windows (git-bash) | `grep -P` unavailable | ~5 tests in `test_data_fetch.bats` | Git Bash ships BusyBox grep without PCRE. Tests pass in CI (Linux). |

If a test fails and uses `grep -P` on Windows, count it as a known limitation, not a failure.

### Everything else is a real failure

Any test failure that is NOT in the known-limitations table above is a real regression. Investigate it.

## Step 5: Report Summary

Report results in this format:

```
ShellCheck: PASS (N files checked)
BATS: X/Y tests passed. Z skipped. N known platform limitations. M real failures.
```

If there are real failures, list each one with the test name and error output.
