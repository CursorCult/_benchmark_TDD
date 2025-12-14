#!/usr/bin/env bash
set -euo pipefail

# Usage: ./run_all.sh [output_dir]

root="$(cd "$(dirname "$0")" && pwd)"
output_dir="${1:-}"

"$root/doctor.sh" >/dev/null
("$root/setup_env.sh" >/dev/null)

cases=()
while IFS= read -r d; do
  cases+=("$d")
done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -name "[0-9][0-9][0-9]" | sort)

if [[ "${#cases[@]}" -eq 0 ]]; then
  echo "no cases found under $root" >&2
  exit 1
fi

for case_dir in "${cases[@]}"; do
  case_name="$(basename "$case_dir")"
  echo "=== $case_name ==="
  (cd "$case_dir" && ./run.sh)
  
  if [[ -n "$output_dir" ]]; then
    mkdir -p "$output_dir/$case_name"
    cp "$case_dir/off.json" "$output_dir/$case_name/off.json"
    cp "$case_dir/on.json" "$output_dir/$case_name/on.json"
  fi
done

echo "done"
