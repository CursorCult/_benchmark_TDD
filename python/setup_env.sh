#!/usr/bin/env bash
set -euo pipefail

# Creates a shared virtual environment for all Python benchmarks.

script_dir="$(cd "$(dirname "$0")" && pwd)"
venv_dir="$script_dir/.venv"
req_file="$script_dir/requirements.txt"

if [[ ! -f "$req_file" ]]; then
  echo "Error: requirements.txt not found at $req_file" >&2
  exit 1
fi

if [[ ! -d "$venv_dir" ]]; then
  echo "Creating venv at $venv_dir..."
  python3 -m venv "$venv_dir"
fi

echo "Installing dependencies..."
"$venv_dir/bin/python" -m pip install --disable-pip-version-check -q -r "$req_file"

echo "Shared venv ready at $venv_dir"
