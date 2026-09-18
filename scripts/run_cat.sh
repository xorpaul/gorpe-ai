#!/usr/bin/env bash
set -euo pipefail
# Path-restricted cat for gorpe remote debugging (run_cat_wild).
# Runs as root via sudo so root-owned config files are readable.
# Only /etc/shadow and /etc/gshadow are denied; all other absolute paths are allowed.

path="${1:-}"

[[ -z "$path" ]] && { echo "ERROR: path argument required" >&2; exit 1; }
[[ "$path" != /* ]] && { echo "ERROR: absolute path required" >&2; exit 1; }
[[ "$path" == *..* ]] && { echo "ERROR: path traversal not allowed" >&2; exit 1; }

denied_prefixes=(/etc/shadow /etc/gshadow)
for denied in "${denied_prefixes[@]}"; do
  if [[ "$path" == "${denied}"* ]]; then
    echo "ERROR: path not allowed: $path" >&2
    exit 1
  fi
done

if [[ ! -f "$path" ]]; then
  echo "ERROR: not a regular file: $path" >&2
  exit 1
fi

exec cat "$path"
