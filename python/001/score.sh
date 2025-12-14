#!/usr/bin/env bash
set -euo pipefail

mode="${1:?usage: ./score.sh <on|off>}"
mode_dir="$(cd "$(dirname "$0")" && pwd)/$mode"
repo_dir="$mode_dir/repo"
artifacts_dir="$mode_dir/artifacts"

metrics_dir="${METRICS_DIR:-}"
if [[ -z "$metrics_dir" ]]; then
  echo "METRICS_DIR not set (expected to point at CursorCult/_metrics checkout)" >&2
  exit 1
fi

base_sha="$(cat "$artifacts_dir/base_sha.txt")"
agent_rc="$(cat "$artifacts_dir/agent_rc.txt" 2>/dev/null || echo 1)"
commits=()
if [[ -f "$artifacts_dir/new_commits.txt" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    commits+=("$line")
  done < "$artifacts_dir/new_commits.txt"
fi

commit_count="${#commits[@]}"
commit_count_ok=0
if [[ "$commit_count" -eq 2 ]]; then
  commit_count_ok=1
fi

commit_tests="${commits[0]:-}"
commit_impl="${commits[1]:-}"

pushd "$repo_dir" >/dev/null

tests_only_ok=0
red_ok=0
green_ok=0
head_ok=0
coverage_percent=""

head_sha="$(git rev-parse HEAD)"

if [[ "$agent_rc" -eq 0 ]]; then
  set +e
  python3 -m pytest >/dev/null 2>&1
  head_rc=$?
  set -e
  if [[ "$head_rc" -eq 0 ]]; then
    head_ok=1
    python3 -m coverage run --source=src -m pytest >/dev/null 2>&1
    python3 -m coverage json -o coverage.json >/dev/null 2>&1
    coverage_percent="$(python3 "$metrics_dir/python/code_coverage.py" coverage.json)"
  fi
fi

if [[ "$commit_count" -eq 2 ]]; then
  changed_files="$(git diff --name-only "$base_sha..$commit_tests" || true)"
  tests_only_ok=1
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if [[ "$f" == tests/* ]]; then
      continue
    fi
    tests_only_ok=0
    break
  done <<< "$changed_files"

  git checkout -q "$commit_tests"
  set +e
  python3 -m pytest >/dev/null 2>&1
  rc1=$?
  set -e
  if [[ "$rc1" -ne 0 ]]; then
    red_ok=1
  fi

  git checkout -q "$commit_impl"
  set +e
  python3 -m pytest >/dev/null 2>&1
  rc2=$?
  set -e
  if [[ "$rc2" -eq 0 ]]; then
    green_ok=1
  fi

  git checkout -q main
fi

popd >/dev/null

# Compliance score in [0,1]:
# - strict: only score compliance if there are exactly 2 commits
compliance_score="$(python3 - <<PY
cc = $commit_count_ok
if cc != 1:
    print(0.0)
else:
    print(($tests_only_ok + $red_ok + $green_ok) / 3.0)
PY
)"

coverage_score="$(python3 - <<PY
cov = "${coverage_percent}"
try:
    cov_f = float(cov)
except Exception:
    cov_f = 0.0
print(max(0.0, min(1.0, cov_f / 100.0)))
PY
)"

quality_score="$(python3 - <<PY
head_ok = $head_ok
cov = float("$coverage_score")
print(0.5 * head_ok + 0.5 * cov)
PY
)"

score="$(python3 - <<PY
cs = float("$compliance_score")
qs = float("$quality_score")
print(max(0.0, min(1.0, 0.8 * cs + 0.2 * qs)))
PY
)"

python3 - <<PY
import json
cov_raw = "${coverage_percent}"
cov = None
if cov_raw.strip():
  cov = float(cov_raw)
print(json.dumps({
  "case": "001",
  "mode": "$mode",
  "agent_rc": int("$agent_rc"),
  "base_sha": "$base_sha",
  "head_sha": "$head_sha",
  "commits": {
    "count": $commit_count,
    "tests": "$commit_tests",
    "impl": "$commit_impl",
  },
  "signals": {
    "commit_count_ok": $commit_count_ok,
    "tests_only_ok": $tests_only_ok,
    "red_ok": $red_ok,
    "green_ok": $green_ok,
    "head_ok": $head_ok,
  },
  "metrics": {
    "code_coverage_percent": cov,
  },
  "components": {
    "compliance_score": float("$compliance_score"),
    "quality_score": float("$quality_score"),
  },
  "score": float("$score"),
}, indent=2, sort_keys=True))
PY
