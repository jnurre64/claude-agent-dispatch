# Future: Channel-Based Architecture

This document tracks the planned evolution from webhook notifications and Discord bot interactions to a Claude Code Channel-based architecture.

## Current Status

**Not planned for implementation.** This is a roadmap item contingent on upstream changes from Anthropic.

## Trigger to Revisit

Any of these changes from Anthropic would make this viable:

- Claude Code Channels work with `claude -p` (headless mode)
- Channels support API key or subscription-based auth (not just claude.ai login)
- A stable (non-research-preview) release of Channels with a settled API contract

## What It Would Look Like

A custom webhook channel (MCP server) receives GitHub events and dispatch notifications. Claude in a persistent session acts as a coordinator — it receives events, reasons about them, and communicates via Discord and/or Telegram. Implementation still happens via `claude -p` dispatch.

## What It Would Enable

- Natural conversation with the agent from Discord/Telegram
- Proactive context surfacing across issues
- Multi-platform support from a single session

## Preparation

Phases 1 and 2 are designed to make this transition smooth:

- The `notify()` interface is generic (structured data, not Discord-specific)
- GitHub labels and comments remain the source of truth for dispatch state
- No Discord-only state is introduced

## References

- [Claude Code Channels documentation](https://code.claude.com/docs/en/channels)
- [Channels reference (building custom channels)](https://code.claude.com/docs/en/channels-reference)
- Design spec: `docs/superpowers/specs/2026-03-22-dispatch-notify-design.md`
