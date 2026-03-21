# Contributing

Thanks for your interest in contributing to claude-agent-dispatch!

## How to Contribute

1. **Fork** the repository
2. **Create a branch** for your change: `git checkout -b my-feature`
3. **Make your changes** — follow the conventions below
4. **Run ShellCheck** before submitting: `shellcheck scripts/*.sh scripts/lib/*.sh`
5. **Submit a pull request** with a clear description of what changed and why

## Conventions

- Shell scripts use `bash` with `set -euo pipefail`
- All scripts must pass [ShellCheck](https://www.shellcheck.net/) with zero warnings
- Use kebab-case for file names, SCREAMING_SNAKE_CASE for environment variables
- Keep functions focused — one clear purpose per function
- Add comments explaining "why", not "what"

## Reporting Issues

Open an issue with:
- What you expected to happen
- What actually happened
- Steps to reproduce
- Your environment (OS, shell version, Claude Code version)

## Questions?

Open a discussion or issue — happy to help.
