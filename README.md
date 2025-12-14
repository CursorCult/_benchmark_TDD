# `_benchmark_TDD`

Benchmark harness for the CursorCult `TDD` rule.

## Prerequisites

1.  **`cursor-agent` installed**: The CLI tool must be in your PATH.
2.  **Authenticated**: Run `cursor-agent login` before starting (or ensure you have a valid session).
3.  **Cost Awareness**: Benchmark runs invoke real LLM inference, which may incur API costs and time.

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
cd python/simple_add
CURSOR_AGENT_MODEL=auto ./run.sh
```

## License

Unlicense / public domain. See `LICENSE`.
