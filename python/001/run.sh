#!/usr/bin/env bash
set -euo pipefail

case_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$case_dir/../.." && pwd)"

run_mode () {
  local mode="$1"
  local rules="${2:-}"

  "$case_dir/setup.sh" "$mode"
  pushd "$case_dir/$mode" >/dev/null
  if [[ -n "$rules" ]]; then
    "$case_dir/benchmark.sh" "$rules"
  else
    "$case_dir/benchmark.sh"
  fi
  popd >/dev/null
}

run_mode off
METRICS_DIR="${METRICS_DIR:-$root_dir/../_metrics}" "$case_dir/score.sh" off > "$case_dir/off.json"

run_mode on "$root_dir/RULES.txt"
METRICS_DIR="${METRICS_DIR:-$root_dir/../_metrics}" "$case_dir/score.sh" on > "$case_dir/on.json"

echo "wrote: $case_dir/off.json $case_dir/on.json"

