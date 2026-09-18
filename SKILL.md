---
name: gorpe
description: "Run remote commands and checks against Linux hosts by making direct HTTPS calls to the gorpe daemon. USE WHEN: running a puppet agent on a remote host, tailing the journal of a service, running a disk/memory/process check, reading a log file remotely, debugging why a host is misbehaving, or running any other gorpe command. When direct gorpe port access is blocked, proxy through a monitoring server using run_gorpe_proxy. Keywords: gorpe, nrpe, nagios, puppet agent, puppet run, tail journal, check service, remote check, mTLS, proxy, monitoring VLAN, firewall blocked."
argument-hint: "<remote-fqdn-or-ip> <task or gorpe command> [optional ARG]"
---

# Gorpe Remote Command Runner

Call the gorpe daemon directly over HTTPS using `curl`. No intermediate MCP server is needed — gorpe's own HTTP API returns the command output and exit code as JSON.

## HTTP API

gorpe listens on port 5667 (HTTPS). Every command in `gorpe.yaml` maps to a URL path.

**No argument:**
```bash
curl -sk --cert CERT --key KEY -H "Accept: application/json" https://HOST:5667/COMMAND
```

**With argument (`$ARG$` commands):**
```bash
curl -sk --cert CERT --key KEY -H "Accept: application/json" -d "arg1=ARG_VALUE" https://HOST:5667/COMMAND
```

Response: `{"exit_code": N, "output": "..."}` — always check `exit_code`.

The `-s` flag silences curl progress; `-k` skips server certificate verification (gorpe daemons may use self-signed certs). Authentication is provided by the client certificate (`--cert` / `--key`), not by verifying the server cert.

## Prerequisites

The machine running the curl call must:
1. Have a valid TLS client certificate whose CA is trusted by the target's gorpe daemon
2. Have its IP address listed in the target's `allowed_ips` (in `/etc/gorpe/gorpe.yaml`)

Set `CERT` and `KEY` to the paths of that client certificate and private key.

## Procedure

### Step 1 — Direct or proxy?

**Always try the target host directly first.** Only fall back to a proxy (see [Monitoring-server proxy](#monitoring-server-proxy)) if the direct attempt fails with a connection error.

### Step 2 — Map the user's intent to a gorpe command

| User intent | Command | Arg |
|---|---|---|
| "Run puppet on X" | `run_puppet_agent` | — |
| "Dry-run puppet on X" | `run_puppet_agent_noop` | — |
| "Show last puppet run" | `check_journalctl_puppet` **and** `check_journalctl_puppet_agent` | — |
| "Tail \<unit\> logs on X" | `check_journalctl_unit` | unit name |
| "Status of \<unit\> on X" | `check_systemctl_status_unit` | unit name |
| "Quick overview / is X healthy" | `run_glances` | — |
| "What services are running on X" | `run_systemctl_list` | — |
| "Is X up / reachable" | `check_w` | — |
| "What ports are listening on X" | `run_ss_wild` | `-tulpn` |
| "Disk usage on X" | `run_df` | — |
| "Memory on X" | `run_free` | — |
| "Process list on X" | `run_ps` | — |
| "Kernel messages on X" | `run_dmesg` | — |
| "Read file \<path\> on X" | `run_stat_wild` (size first) then `run_cat_wild` | file path |

### Step 3 — Build and run the curl command

No-argument example:
```bash
curl -sk --cert /etc/gorpe/ssl/cert.pem --key /etc/gorpe/ssl/key.pem \
  -H "Accept: application/json" \
  https://web01.example.com:5667/run_df
```

Argument example (unit name for `check_journalctl_unit`):
```bash
curl -sk --cert /etc/gorpe/ssl/cert.pem --key /etc/gorpe/ssl/key.pem \
  -H "Accept: application/json" \
  -d "arg1=nginx" \
  https://web01.example.com:5667/check_journalctl_unit
```

Puppet run:
```bash
curl -sk --cert /etc/gorpe/ssl/cert.pem --key /etc/gorpe/ssl/key.pem \
  -H "Accept: application/json" \
  https://web01.example.com:5667/run_puppet_agent
```

### Step 4 — Interpret the result

Parse the JSON response. For all commands:

| `exit_code` | Meaning |
|---|---|
| 0 | OK / success |
| 1 | WARNING |
| 2 | CRITICAL / **for `run_puppet_agent`: changes applied successfully** — this is GOOD |
| 3 | Transport error (connection refused, TLS failure, timeout) |
| 4 | `run_puppet_agent` only: resource failures |
| 6 | `run_puppet_agent` only: changes applied AND some failures |

Always translate puppet exit codes — exit 2 means "changes applied", not "critical".

## Monitoring-server proxy

When the target host's port 5667 is not reachable from your machine, route through a monitoring server that does have access using the `run_gorpe_proxy` command:

```bash
curl -sk --cert /etc/gorpe/ssl/cert.pem --key /etc/gorpe/ssl/key.pem \
  -H "Accept: application/json" \
  -d "arg1=target-host.example.com run_df" \
  https://monitoring-server.example.com:5667/run_gorpe_proxy
```

For commands that take an argument, append it after the command name in the `arg1` value:

```bash
-d "arg1=target-host.example.com check_journalctl_unit nginx"
```

The monitoring server must have `run_gorpe_proxy` in its `gorpe.yaml` `commands:` section and must accept connections from your IP.

## Remote debugging commands

The `run_*` commands return raw shell output. Use them for ad-hoc investigation.

### Quick-reference table

| Intent | Command | `arg1` value | Notes |
|---|---|---|---|
| Quick resource overview | `run_glances` | — | CPU, mem, load, disk, network |
| Disk usage (all mounts) | `run_df` | — | `df -h` |
| Disk usage (specific) | `run_df_wild` | `/var` or `-i` | |
| Block devices | `run_lsblk` | — | |
| Memory | `run_free` | — | `free -h` |
| Load average | `run_uptime` | — | |
| CPU info | `run_lscpu` | — | |
| Disk I/O stats | `run_iostat_wild` | `-xd 1 3` | 3 samples, 1s apart |
| Process list | `run_ps` | — | `ps auxf` |
| IP addresses | `run_ip_addr` | — | `ip addr show` |
| Routing table | `run_ip_route` | — | `ip route show` |
| Any `ip` subcommand | `run_ip_wild` | `neigh show` | raw `ip $ARG$` |
| Socket/connection list | `run_ss_wild` | `-tulpn` | `sudo ss $ARG$` |
| Firewall rules (iptables) | `run_iptables_list` | — | empty on nft-only hosts |
| Firewall rules (nft) | `run_nft_list` | — | |
| Kernel ring buffer | `run_dmesg` | — | `dmesg -T` |
| All systemd units | `run_systemctl_list` | — | |
| Flexible journal query | `run_journalctl_wild` | `-u nginx -n 100` | `journalctl $ARG$ --no-pager` |
| Read a file | `run_cat_wild` | `/etc/nginx/nginx.conf` | **check size first** |
| Tail a file | `run_tail_wild` | `-n 200 /var/log/syslog` | |
| Grep a file | `run_grep_wild` | `-i error /var/log/syslog` | exit 1 = no matches (not an error) |
| Grep a gzip log | `run_zgrep_wild` | `-i error /var/log/syslog.1.gz` | file path must be last |
| Tail a gzip log | `run_ztail_wild` | `-n 200 /var/log/syslog.1.gz` | |
| Directory listing | `run_ls_wild` | `-la /etc/nginx/` | |
| File metadata | `run_stat_wild` | `/etc/nginx/nginx.conf` | check size before `run_cat_wild` |

### File size check before `run_cat_wild`

**Always check file size first** — reading a large log file dumps its entire contents into the response. Use `run_stat_wild` or `run_ls_wild` to check size first. If larger than ~1 MB, use `run_tail_wild`, `run_grep_wild`, or `run_awk_wild` instead.

### Path restrictions for file commands

`run_cat_wild`, `run_tail_wild`, `run_grep_wild`, `run_awk_wild`, `run_sed_wild`, and all compressed-log commands (`run_z*`, `run_bz*`):
- Path must be absolute; `..` is rejected
- `/etc/shadow` and `/etc/gshadow` are denied
- All other absolute paths are allowed

## Common pitfalls

- **Connection refused on port 5667** — gorpe is down on the target, or your IP is not in `allowed_ips`. Check `systemctl status gorpe` on the target.
- **TLS handshake failure** — the cert/key pair is not trusted by the target's gorpe. Check that the target's `ca_file` includes the CA that signed your client cert.
- **`sudo: a terminal is required to read the password`** — the target's `/etc/sudoers.d/gorpe` is missing a `NOPASSWD` entry for the command. Update the sudoers file.
- **Long-running commands (puppet, iostat)** — gorpe has a `command_timeout` (default 600s). Commands that exceed it are killed; the connection drops with a TLS error rather than a clean response.
- **puppet-agent log scoping** — `check_journalctl_puppet` only shows lines from `puppet.service`. Interactive `puppet agent -t` runs are logged under `puppet-agent` with no unit attribution — invisible to `-u puppet`. Always also run `check_journalctl_puppet_agent` when asking about a puppet run result.

## Worked example

> "run puppet on web01.example.com and show me what changed"

```bash
curl -sk --cert /etc/gorpe/ssl/cert.pem --key /etc/gorpe/ssl/key.pem \
  -H "Accept: application/json" \
  https://web01.example.com:5667/run_puppet_agent
# → {"exit_code": 2, "output": "Notice: Applied catalog in 54.07 seconds ..."}
```

Exit 2 from `run_puppet_agent` = changes applied successfully. Report this as success, not as CRITICAL.
