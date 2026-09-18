# gorpe-ai — AI agent guidance

For AI tools that support instruction files: see **[SKILL.md](SKILL.md)** for the complete guide on calling the gorpe HTTP API directly with curl to run remote commands on managed Linux hosts.

SKILL.md covers:
- The gorpe HTTP API (GET / POST, JSON response format)
- When to call the target directly vs. routing through a proxy via `run_gorpe_proxy`
- Intent → command mapping for common tasks (puppet runs, log tailing, disk/memory checks, file reading)
- Exit code interpretation (especially for puppet's detailed exit codes)
- Remote debugging command reference with `arg1` examples
- Common pitfalls and how to avoid them
