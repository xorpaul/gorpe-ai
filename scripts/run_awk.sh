#!/usr/bin/env bash
set -euo pipefail
# Path-restricted awk for gorpe run_awk_wild.
# File path must be the last argument; same allow/deny rules as run_cat.sh.
# Example: -a "'/final cacheSize/{print $NF}' /var/log/ehbackup/bkschd-master_debug.log"

[[ $# -eq 0 ]] && { echo "ERROR: arguments required" >&2; exit 1; }

# Gorpe may deliver all of $ARG$ as a single whitespace-separated token; re-split
# so flags and the file path each become their own positional parameter.
if [[ $# -eq 1 ]]; then
    read -ra _args <<< "$1"
    set -- "${_args[@]}"
fi

path="${*: -1}"

[[ "$path" != /* ]] && { echo "ERROR: absolute path required" >&2; exit 1; }
[[ "$path" == *..* ]] && { echo "ERROR: path traversal not allowed" >&2; exit 1; }

denied_prefixes=(/etc/shadow /etc/gshadow)
for denied in "${denied_prefixes[@]}"; do
  [[ "$path" == "${denied}"* ]] && { echo "ERROR: path not allowed: $path" >&2; exit 1; }
done

[[ ! -f "$path" ]] && { echo "ERROR: not a regular file: $path" >&2; exit 1; }

exec awk "$@"
