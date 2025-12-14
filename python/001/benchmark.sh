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

python3 -c "import sys; print(sys.version.split()[0])" > "$artifacts_dir/python_version.txt"

if [[ -n "$rules_file" ]]; then
  mkdir -p .cursor/rules
  rule_ref="${BENCH_RULE_REF:-v0}"

  install_rule_from_git () {
    local name="$1"
    local ref="$2"
    local url="https://github.com/CursorCult/${name}.git"

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    # Try as a branch first, then fall back to fetching and checking out the ref.
    if git clone -q --depth 1 --branch "$ref" "$url" "$tmp/repo" 2>/dev/null; then
      :
    else
      git clone -q --no-checkout "$url" "$tmp/repo"
      git -C "$tmp/repo" checkout -q "$ref"
    fi

    if [[ ! -f "$tmp/repo/RULE.md" ]]; then
      echo "Rule repo missing RULE.md at ref '$ref': $url" >&2
      exit 1
    fi

    mkdir -p ".cursor/rules/$name"
    cp "$tmp/repo/RULE.md" ".cursor/rules/$name/RULE.md"
    [[ -f "$tmp/repo/README.md" ]] && cp "$tmp/repo/README.md" ".cursor/rules/$name/README.md" || true
    [[ -f "$tmp/repo/LICENSE" ]] && cp "$tmp/repo/LICENSE" ".cursor/rules/$name/LICENSE" || true
  }

  while IFS= read -r line; do
    name="$(echo "$line" | awk '{print $1}')"
    [[ -z "$name" ]] && continue
    [[ "$name" == \#* ]] && continue
    if [[ ! -f ".cursor/rules/$name/RULE.md" ]]; then
      install_rule_from_git "$name" "$rule_ref"
    fi

    # Cursor rules live at `.cursor/rules/<NAME>/RULE.md`.
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

model="${CURSOR_AGENT_MODEL:-auto}"
cmd=( cursor-agent -p -f --model "$model" agent "$prompt_text" )

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
