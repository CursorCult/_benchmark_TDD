# Python benchmarks

## Prerequisites

1.  **`cursor-agent` installed**: The CLI tool must be in your PATH.
2.  **Authenticated**: Run `cursor-agent login`.
3.  **Cost Awareness**: Runs invoke real LLM inference.

Each directory is a benchmark case. Currently available cases:
- `simple_add`: Basic function addition, no explicit TDD prompt.
- `simple_add_prompted`: Basic function addition, with explicit TDD instructions in the prompt.
- `stack_ds`: More complex data structure implementation (Stack).

All cases must run for an aggregate score.

`weights.json` assigns a weight per case; weights are normalized to sum to 1.0.

## Setup

Create the shared Python environment once:

```sh
./setup_env.sh
```

## Run

- One case: `cd simple_add && ./run.sh`
- All cases: `./run_all.sh` (outputs results to local `off.json`/`on.json` for each case)
