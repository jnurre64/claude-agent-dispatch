# Discord Notifications

Optional Discord notifications for agent dispatch milestones. When configured, the dispatch system sends rich embed messages to a Discord channel at key events.

## Quick Start

1. Create a Discord webhook: Server Settings > Integrations > Webhooks > New Webhook
2. Copy the webhook URL
3. Add to your `config.env`:

   ```bash
   AGENT_NOTIFY_DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_ID/YOUR_TOKEN"
   ```

4. (Optional) Set the notification level:

   ```bash
   # "all" — every milestone
   # "actionable" — events needing user response (default)
   # "failures" — only failures
   AGENT_NOTIFY_LEVEL="actionable"
   ```

5. (Optional) Post to a specific thread:

   ```bash
   AGENT_NOTIFY_DISCORD_THREAD_ID="123456789"
   ```

## Events

| Event | Level | When |
|---|---|---|
| Plan Ready | `actionable` | Agent has triaged an issue and posted a plan |
| Questions | `actionable` | Agent needs clarification before planning |
| Implementation Started | `all` | Agent begins implementing an approved plan |
| Tests Passed | `all` | Pre-PR test gate passed |
| Tests Failed | `failures` | Pre-PR test gate failed |
| PR Created | `actionable` | Agent created a pull request |
| Review Feedback | `actionable` | Agent is addressing PR review comments |
| Agent Failed | `failures` | Agent encountered an error |

## Notification Levels

- **`all`** — Every event above is sent
- **`actionable`** (default) — Only events that may need your attention
- **`failures`** — Only `tests_failed` and `agent_failed`

## Security

- The webhook URL is stored in `config.env` which is not committed to git
- Notifications are sent via HTTPS to Discord's API
- No user data is collected or stored
- All notifications include an "Automated by claude-agent-dispatch" footer

## Phase 2: Interactive Bot

A future phase will add a Discord bot with interactive buttons (Approve, Request Changes, Comment) and slash commands, enabling two-way interaction from Discord. See the design spec for details.
