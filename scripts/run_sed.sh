#!/usr/bin/env bash
set -euo pipefail
# Path-restricted sed for gorpe run_sed_wild.
# File path must be the last argument; same allow/deny rules as run_cat.sh.
# In-place editing (-i / --in-place) is blocked — read-only use only.
# Example: -a "'s/DEBUG--//g' /var/log/ehbackup/bkschd-master_debug.log"

[[ $# -eq 0 ]] && { echo "ERROR: arguments required" >&2; exit 1; }

# Gorpe may deliver all of $ARG$ as a single whitespace-separated token; re-split
# so flags and the file path each become their own positional parameter.
if [[ $# -eq 1 ]]; then
    read -ra _args <<< "$1"
    set -- "${_args[@]}"
fi

for arg in "$@"; do
  case "$arg" in
    -i*|--in-place*) echo "ERROR: in-place editing not allowed" >&2; exit 1 ;;
  esac
done

path="${*: -1}"

[[ "$path" != /* ]] && { echo "ERROR: absolute path required" >&2; exit 1; }
[[ "$path" == *..* ]] && { echo "ERROR: path traversal not allowed" >&2; exit 1; }

denied_prefixes=(/etc/shadow /etc/gshadow)
for denied in "${denied_prefixes[@]}"; do
  [[ "$path" == "${denied}"* ]] && { echo "ERROR: path not allowed: $path" >&2; exit 1; }
done

[[ ! -f "$path" ]] && { echo "ERROR: not a regular file: $path" >&2; exit 1; }

exec sed "$@"
