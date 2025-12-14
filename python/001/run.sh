#!/usr/bin/env bash
set -euo pipefail

case_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$case_dir/../.." && pwd)"
python_root="$(cd "$case_dir/.." && pwd)"

if [[ ! -x "$python_root/.venv/bin/python" ]]; then
  (cd "$python_root" && ./setup_env.sh)
fi

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
"$case_dir/score.sh" off > "$case_dir/off.json"

run_mode on "$root_dir/RULES.txt"
"$case_dir/score.sh" on > "$case_dir/on.json"

echo "wrote: $case_dir/off.json $case_dir/on.json"
