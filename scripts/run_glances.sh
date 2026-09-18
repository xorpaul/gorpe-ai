#!/usr/bin/env bash
# Non-interactive glances snapshot for gorpe remote debugging.
# Uses --stdout mode with a 2-second timeout to capture one sample and exit.
# PYTHONUNBUFFERED=1 prevents pipe buffering that would suppress output.
#
# Usage: run_glances.sh [plugin1,plugin2,...]
# Default plugins: cpu,mem,memswap,load,diskio,fs,network
# Examples:
#   run_glances.sh                    -> all default plugins
#   run_glances.sh cpu,diskio         -> CPU and disk I/O only
#
# gorpe invocation:
#   check_gorpe ... -c run_glances
#   check_gorpe ... -c run_glances_wild -a "cpu,diskio"

PLUGINS="${1:-cpu,mem,memswap,load,diskio,fs,network}"

GLANCES=
for candidate in /usr/bin/glances /usr/local/bin/glances; do
  if [[ -x "$candidate" ]]; then
    GLANCES="$candidate"
    break
  fi
done

if [[ -z "$GLANCES" ]]; then
  echo "ERROR: glances is not installed on this host" >&2
  exit 1
fi

PYTHONUNBUFFERED=1 timeout 5 "$GLANCES" --stdout "$PLUGINS" -t 1 2>/dev/null | head -n 200
exit 0
