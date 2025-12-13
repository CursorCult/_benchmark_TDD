# `_benchmark_TDD`

Benchmark harness for the CursorCult `TDD` rule.

## How it works (high level)

Each case lives under `python/<case>/` and runs twice:

- `off/`: no rules applied
- `on/`: run the same benchmark but provide `RULES.txt` (contains `TDD`)

The benchmark is a single agent run per mode; we do **not** force multi-prompt phases.
Instead, we inspect the git commit history produced by the agent.

Expected shape for compliance:

- exactly **2 commits** after the initial baseline
  - commit 1: tests (should fail)
  - commit 2: implementation (should pass)

## Running (one case)

```sh
cd python/001
./run.sh
```

## License

Unlicense / public domain. See `LICENSE`.

