# claude-agent-dispatch

Reusable agent dispatch system for Claude Code — label-driven GitHub Actions workflows for autonomous issue triage, planning, implementation, and PR review.

> This project is under active development. Full documentation coming soon.

## What This Does

When you label a GitHub issue with `agent`, this system:

1. **Triages** the issue — reads CLAUDE.md, explores the codebase, decides if it needs clarification
2. **Plans** — writes a detailed implementation plan and posts it for human review
3. **Implements** — after plan approval, follows TDD (red-green-refactor) to make changes
4. **Creates a PR** — with test evidence and a summary of what changed
5. **Addresses review feedback** — when a reviewer requests changes, the agent fixes them
6. **Cleans up** — stale branches, orphaned gists, old workflow runs (scheduled)

All orchestrated through a label state machine (`agent:triage` → `agent:plan-review` → `agent:in-progress` → `agent:pr-open`) with circuit breakers, worktree isolation, and configurable prompts.

## Quick Start

```bash
# Clone onto your runner
git clone https://github.com/jnurre64/claude-agent-dispatch.git ~/agent-infra
cd ~/agent-infra

# Configure for your project
cp config.env.example config.env
# Edit config.env with your bot username, test command, etc.

# Create labels on your repo
./scripts/create-labels.sh your-org/your-repo

# Check prerequisites
./scripts/check-prereqs.sh
```

Then add caller workflows to your project repo (see `docs/getting-started.md` — coming soon).

## Requirements

- Self-hosted GitHub Actions runner with `claude` CLI installed
- `gh` CLI authenticated as a bot account
- `git`, `jq`, `curl`

## License

MIT
