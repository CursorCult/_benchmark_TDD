#!/usr/bin/env bash
set -euo pipefail

# Generic scoring script for TDD benchmarks.
# Sourced by case-specific score.sh files.

mode="${1:?usage: ./score.sh <on|off>}"
case_dir="$(cd "$(dirname "$0")" && pwd)"
case_name="$(basename "$case_dir")"
mode_dir="$case_dir/$mode"
repo_dir="$mode_dir/repo"
artifacts_dir="$mode_dir/artifacts"
venv_python="$case_dir/../.venv/bin/python"

if [[ ! -x "$venv_python" ]]; then
  echo "missing shared venv at $venv_python" >&2
  exit 1
fi

base_sha="$(cat "$artifacts_dir/base_sha.txt")"
agent_rc="$(cat "$artifacts_dir/agent_rc.txt" 2>/dev/null || echo 1)"

pushd "$repo_dir" >/dev/null

# 1. Coverage (if available)
coverage_percent=0.0
coverage_available=0
if "$venv_python" -m coverage --version >/dev/null 2>&1; then
  coverage_available=1
fi

# 2. Analyze Commits
# We want to trace the sequence of changes: [T]* -> [I]*
# T = Tests only
# I = Impl only (src/)
# M = Mixed
# O = Other (config, etc)

commits=($(git rev-list --reverse "$base_sha..HEAD"))
commit_count="${#commits[@]}"
commit_types=()
last_test_commit=""

# Only check logic if we have commits
if [[ "$commit_count" -gt 0 ]]; then
  for sha in "${commits[@]}"; do
    has_src=0
    has_test=0
    
    # Analyze modified files in this commit
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      if [[ "$f" == src/* ]]; then has_src=1; fi
      if [[ "$f" == tests/* ]]; then has_test=1; fi
    done < <(git show --name-only --format= "$sha")
    
    if [[ "$has_src" -eq 1 && "$has_test" -eq 1 ]]; then
      c_type="M"
    elif [[ "$has_src" -eq 1 ]]; then
      c_type="I"
    elif [[ "$has_test" -eq 1 ]]; then
      c_type="T"
    else
      c_type="O"
    fi
    
    commit_types+=("$c_type")
    if [[ "$c_type" == "T" ]]; then last_test_commit="$sha"; fi
  done
fi

# 3. Evaluate Compliance (Structure)
compliance_ok=1
seen_t=0
seen_i=0
phase="red"

if [[ "$commit_count" -ne 2 ]]; then
  compliance_ok=0
else
  if [[ "${commit_types[0]}" == "T" ]]; then seen_t=1; fi
  if [[ "${commit_types[1]}" == "I" ]]; then seen_i=1; fi
  if [[ "$seen_t" -ne 1 || "$seen_i" -ne 1 ]]; then
    compliance_ok=0
  fi
fi

# 4. Evaluate Semantics (Red/Green State)
red_ok=0
green_ok=0
head_ok=0

# Check RED State (must be evaluated at the last TEST_ONLY commit before any IMPL)
if [[ -n "$last_test_commit" ]]; then
  git checkout -q "$last_test_commit"
  
  # Environment Check: Baseline smoke test must pass
  # Note: If agent modifies test_smoke.py and breaks it, this fails (0).
  if "$venv_python" -m unittest tests/test_smoke.py >/dev/null 2>&1; then
    # Full Suite: Must FAIL
    if ! "$venv_python" -m unittest discover -s tests -p "test_*.py" >/dev/null 2>&1; then
      red_ok=1
    fi
  fi
fi

# Check GREEN State (HEAD)
git checkout -q main
if "$venv_python" -m unittest discover -s tests -p "test_*.py" >/dev/null 2>&1; then
  green_ok=1
  head_ok=1
  
  # Calculate coverage if GREEN
  if [[ "$coverage_available" -eq 1 ]]; then
    "$venv_python" -m coverage run --source=src -m unittest discover -s tests -p "test_*.py" >/dev/null 2>&1
    "$venv_python" -m coverage json -o coverage.json >/dev/null 2>&1
    coverage_percent="$("$venv_python" - <<'PY'
import json
try:
    with open("coverage.json", "r") as f:
        print(float(json.load(f).get("totals", {}).get("percent_covered", 0.0)))
except:
    print(0.0)
PY
)"
  fi
fi

popd >/dev/null

# 5. Compute Final Score
# Formula: Compliance * (0.5 * Red + 0.5 * Green)
# If not compliant, score is 0.
# If compliant, score depends on actually failing tests first and passing them later.

score="$(python3 - <<PY
comp = $compliance_ok
red = $red_ok
green = $green_ok
if comp == 0:
    print(0.0)
else:
    print(0.5 * red + 0.5 * green)
PY
)"

# 6. JSON Output
python3 - <<PY
import json
print(json.dumps({
  "case": "$case_name",
  "mode": "$mode",
  "agent_rc": int("$agent_rc"),
  "base_sha": "$base_sha",
  "commits": {
    "count": $commit_count,
    "last_test": "$last_test_commit"
  },
  "signals": {
    "compliance_ok": $compliance_ok,
    "seen_t": $seen_t,
    "seen_i": $seen_i,
    "red_ok": $red_ok,
    "green_ok": $green_ok,
    "coverage_available": $coverage_available
  },
  "metrics": {
    "code_coverage_percent": float("$coverage_percent"),
  },
  "score": float("$score")
}, indent=2, sort_keys=True))
PY
