#!/bin/bash
# Proxy a gorpe command to a target host using this monitoring server's own TLS client cert.
# This lets MCP servers or workstations that lack direct gorpe access reach target hosts by
# hopping through a monitoring server that does have access (e.g. sits in the monitoring VLAN).
#
# Called by gorpe when a client invokes the run_gorpe_proxy command:
#   check_gorpe -H monitoring-server -c run_gorpe_proxy \
#     -a "<target-host> <command> [<arg>]"
#
# gorpe expands $ARG$ inline and executes via shell, so the three tokens arrive as
# separate positional parameters $1 $2 $3.

set -euo pipefail

TARGET_HOST="${1:-}"
TARGET_CMD="${2:-}"
TARGET_ARG="${*:3}"

if [[ -z "$TARGET_HOST" || -z "$TARGET_CMD" ]]; then
  echo "UNKNOWN: usage: <target-host> <gorpe-command> [<gorpe-arg>]"
  exit 3
fi

# Use the gorpe-managed copies of the TLS cert/key in /etc/gorpe/ssl/.
# These are owned by the gorpe user and are the same credentials gorpe uses for its own TLS.
CERT="/etc/gorpe/ssl/cert.pem"
KEY="/etc/gorpe/ssl/key.pem"
CA="/etc/gorpe/ssl/ca.pem"
BIN="$(dirname "$0")/check_gorpe"

if [[ ! -x "$BIN" ]]; then
  echo "UNKNOWN: check_gorpe not found at ${BIN} — is this a monitoring server?"
  exit 3
fi

ARGS=(-H "$TARGET_HOST" -p 5667 -cert "$CERT" -key "$KEY" -ca "$CA" -c "$TARGET_CMD")
[[ -n "$TARGET_ARG" ]] && ARGS+=(-a "$TARGET_ARG")

exec "$BIN" "${ARGS[@]}"
