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

base_sha="$(git rev-parse HEAD)"
echo "$base_sha" > "$artifacts_dir/base_sha.txt"

prompt="$case_dir/prompt.md"

# Runner contract:
# - one invocation
# - agent edits this repo and produces commits
# - if rules_file provided, apply those rules
agent_cmd="${CURSOR_AGENT_CMD:-cursor-agent run}"

cmd=( $agent_cmd --prompt "$prompt" )
if [[ -n "$rules_file" ]]; then
  cmd+=( --rules-file "$rules_file" )
fi

printf "%s\n" "${cmd[@]}" > "$artifacts_dir/agent_cmd.txt"

set +e
"${cmd[@]}" 2>&1 | tee "$artifacts_dir/agent.log"
agent_rc="${PIPESTATUS[0]}"
set -e
echo "$agent_rc" > "$artifacts_dir/agent_rc.txt"

git rev-list --reverse "$base_sha..HEAD" > "$artifacts_dir/new_commits.txt" || true

popd >/dev/null

echo "done"

