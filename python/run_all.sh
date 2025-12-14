#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"

"$root/doctor.sh" >/dev/null

cases=()
while IFS= read -r d; do
  cases+=("$d")
done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -name "[0-9][0-9][0-9]" | sort)

if [[ "${#cases[@]}" -eq 0 ]]; then
  echo "no cases found under $root" >&2
  exit 1
fi

for case_dir in "${cases[@]}"; do
  echo "=== $(basename "$case_dir") ==="
  (cd "$case_dir" && ./run.sh)
done

echo "done"

