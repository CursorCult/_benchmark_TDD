# Case 001: Simple feature addition

Goal: ask the agent to add a small, well-specified feature to a tiny Python project.

This case is designed to make “tests-first then implementation” measurable via commits:

- commit 1: add failing tests for the new feature
- commit 2: implement to make tests pass

## Prereqs

None. This case uses stdlib `unittest`.

If `coverage` is available on your machine, the scorer will also report code coverage; otherwise coverage is omitted.
