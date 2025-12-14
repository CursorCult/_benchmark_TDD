#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./benchmark.sh            # OFF: no rules
#   ./benchmark.sh /path/to/RULES.txt

rules_file="${1:-}"
case_dir="$(cd "$(dirname "$0")" && pwd)"
mode_dir="$(pwd)"
repo_dir="$mode_dir/repo"
artifacts_dir="$mode_dir/artifacts"

if [[ ! -d "$repo_dir/.git" ]]; then
  echo "missing repo: $repo_dir (run ./setup.sh first)" >&2
  exit 1
fi

mkdir -p "$artifacts_dir"

pushd "$repo_dir" >/dev/null

python3 -m pip install --disable-pip-version-check -q -r requirements-dev.txt

if [[ -n "$rules_file" ]]; then
  mkdir -p .cursor/rules
  python3 -m pip install --disable-pip-version-check -q cursorcult

  while IFS= read -r line; do
    name="$(echo "$line" | awk '{print $1}')"
    [[ -z "$name" ]] && continue
    [[ "$name" == \#* ]] && continue
    cursorcult copy "$name"
  done < "$rules_file"

  git add .cursor/rules
  if ! git diff --cached --quiet; then
    git commit -m "Apply benchmark rules" -q
  fi
fi

base_sha="$(git rev-parse HEAD)"
echo "$base_sha" > "$artifacts_dir/base_sha.txt"

prompt="$case_dir/prompt.md"

# Runner contract: one invocation; agent edits this repo and produces commits.
prompt_text="$(cat "$prompt")"

cmd=( cursor-agent -p -f agent "$prompt_text" )
if [[ -n "${CURSOR_AGENT_MODEL:-}" ]]; then
  cmd=( cursor-agent -p -f --model "$CURSOR_AGENT_MODEL" agent "$prompt_text" )
fi

printf "%s\n" "${cmd[@]}" > "$artifacts_dir/agent_cmd.txt"

agent_rc=1
attempt=1
delay_s=5
max_attempts="${CURSOR_AGENT_MAX_ATTEMPTS:-4}"
while [[ "$attempt" -le "$max_attempts" ]]; do
  set +e
  "${cmd[@]}" >"$artifacts_dir/agent.log" 2>&1
  agent_rc=$?
  set -e

  if [[ "$agent_rc" -eq 0 ]]; then
    break
  fi

  if grep -qi "resource_exhausted" "$artifacts_dir/agent.log"; then
    echo "cursor-agent resource_exhausted (attempt $attempt/$max_attempts), retrying in ${delay_s}s..." >&2
    sleep "$delay_s"
    delay_s=$((delay_s * 2))
    attempt=$((attempt + 1))
    continue
  fi

  break
done
echo "$agent_rc" > "$artifacts_dir/agent_rc.txt"

git rev-list --reverse "$base_sha..HEAD" > "$artifacts_dir/new_commits.txt" || true

popd >/dev/null

echo "done"
