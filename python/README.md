# Python benchmarks

Each directory is a benchmark case.

All cases must run for an aggregate score.

`weights.json` assigns a weight per case; weights are normalized to sum to 1.0.

## Setup

Create the shared Python environment once:

```sh
./setup_env.sh
```

## Run

- One case: `cd 001 && ./run.sh`
- All cases: `./run_all.sh`
