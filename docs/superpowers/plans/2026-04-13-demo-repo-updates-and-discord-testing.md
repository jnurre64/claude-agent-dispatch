# Demo Repository Updates & Discord Bot Testing Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update both demo repositories (recipe-manager-demo, dodge-the-creeps-demo) to the latest claude-agent-dispatch scripts, create a runner update document for the Discord bot + shared package redeployment, update issue #19 with dual-channel support scope, and create test issues to verify end-to-end Discord bot functionality.

**Architecture:** Both demo repos have `.agent-dispatch/` committed directly (standalone mode, no submodules). Neither has `.upstream` tracking files, so we bootstrap those during the update. The Discord bot runs as a systemd service on the self-hosted runner — a separate document guides that update. The dispatch shell scripts route notifications to the bot's local HTTP API on port 8675.

**Tech Stack:** Bash (shell scripts), GitHub Actions workflows, GitHub CLI (`gh`), Python (Discord bot on runner)

---

## File Structure

### Files modified in recipe-manager-demo (`E:/Git/recipe-manager-demo/`)

| Path | Action | Purpose |
|------|--------|---------|
| `.agent-dispatch/scripts/agent-dispatch.sh` | Replace | Main dispatch — adds review gates, direct implement, per-workflow models |
| `.agent-dispatch/scripts/lib/common.sh` | Replace | New labels, enhanced run_claude with model override |
| `.agent-dispatch/scripts/lib/data-fetch.sh` | Replace | grep -P portability fixes |
| `.agent-dispatch/scripts/lib/defaults.sh` | Replace | New config vars for gates, models, direct implement |
| `.agent-dispatch/scripts/lib/notify.sh` | Replace | Minor header update |
| `.agent-dispatch/scripts/lib/worktree.sh` | Replace | Header update |
| `.agent-dispatch/scripts/lib/config-vars.sh` | Create | Config variable parser for update/setup |
| `.agent-dispatch/scripts/lib/review-gates.sh` | Create | Adversarial plan review + post-impl review gates |
| `.agent-dispatch/scripts/setup.sh` | Replace | Standalone mode default, runner setup guidance |
| `.agent-dispatch/scripts/update.sh` | Replace | Config var tracking, secret detection, interactive migration |
| `.agent-dispatch/scripts/check-prereqs.sh` | Replace | Updated prereqs |
| `.agent-dispatch/scripts/check-test-prereqs.sh` | Create | Test tool checker (jq, shellcheck, bats) |
| `.agent-dispatch/prompts/triage.md` | Replace | Revised question policy (proceed by default) |
| `.agent-dispatch/prompts/implement.md` | Replace | Runtime data gap handling |
| `.agent-dispatch/prompts/CLAUDE.md` | Create | Prompt-to-phase mapping documentation |
| `.agent-dispatch/prompts/adversarial-plan.md` | Create | Gate A: pre-implementation plan review |
| `.agent-dispatch/prompts/post-impl-review.md` | Create | Gate B: post-implementation diff review |
| `.agent-dispatch/prompts/post-impl-retry.md` | Create | Gate B retry: address review concerns |
| `.agent-dispatch/prompts/validate.md` | Create | Direct implement plan validation |
| `.agent-dispatch/.upstream` | Create | Version tracking for future /update runs |
| `.github/workflows/agent-dispatch.yml` | Modify | Add `agent-direct-implement` to repository_dispatch types |
| `.github/workflows/agent-direct-implement.yml` | Create | Workflow for `agent:implement` label trigger |

### Files modified in dodge-the-creeps-demo (`E:/Git/dodge-the-creeps-demo/`)

Same as recipe-manager-demo above (identical `.agent-dispatch/` scripts, different `config.defaults.env`).

### Files created in claude-agent-dispatch (`E:/git/claude-agent-dispatch/`)

| Path | Action | Purpose |
|------|--------|---------|
| `docs/runner-update-plan-phase1.md` | Create | Step-by-step runner update instructions for Phase 1 checkpoint |

---

## Task 1: Update recipe-manager-demo scripts

**Files:**
- Replace: all `.agent-dispatch/scripts/**/*.sh` files (12 files)
- Create: `scripts/lib/config-vars.sh`, `scripts/lib/review-gates.sh`, `scripts/check-test-prereqs.sh`
- Repo: `E:/Git/recipe-manager-demo/`
- Source: `E:/git/claude-agent-dispatch/scripts/`

- [ ] **Step 1: Copy all script files from upstream to demo repo**

```bash
# Copy lib/ files (overwrite existing, add new)
cp E:/git/claude-agent-dispatch/scripts/lib/common.sh      E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/
cp E:/git/claude-agent-dispatch/scripts/lib/config-vars.sh  E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/
cp E:/git/claude-agent-dispatch/scripts/lib/data-fetch.sh   E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/
cp E:/git/claude-agent-dispatch/scripts/lib/defaults.sh     E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/
cp E:/git/claude-agent-dispatch/scripts/lib/notify.sh       E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/
cp E:/git/claude-agent-dispatch/scripts/lib/review-gates.sh E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/
cp E:/git/claude-agent-dispatch/scripts/lib/worktree.sh     E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/

# Copy top-level scripts
cp E:/git/claude-agent-dispatch/scripts/agent-dispatch.sh      E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
cp E:/git/claude-agent-dispatch/scripts/check-prereqs.sh       E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
cp E:/git/claude-agent-dispatch/scripts/check-test-prereqs.sh  E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
cp E:/git/claude-agent-dispatch/scripts/cleanup.sh             E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
cp E:/git/claude-agent-dispatch/scripts/create-labels.sh       E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
cp E:/git/claude-agent-dispatch/scripts/setup.sh               E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
cp E:/git/claude-agent-dispatch/scripts/update.sh              E:/Git/recipe-manager-demo/.agent-dispatch/scripts/
```

- [ ] **Step 2: Verify no regressions in config.defaults.env**

The project-specific `config.defaults.env` must NOT be overwritten. Verify it still contains:
```
AGENT_TEST_COMMAND="dotnet test"
AGENT_EXTRA_TOOLS="Bash(dotnet:*)"
```

- [ ] **Step 3: Spot-check key files were copied correctly**

```bash
# Verify review-gates.sh exists (new file)
head -3 E:/Git/recipe-manager-demo/.agent-dispatch/scripts/lib/review-gates.sh
# Verify agent-dispatch.sh has direct_implement handler
grep "direct_implement" E:/Git/recipe-manager-demo/.agent-dispatch/scripts/agent-dispatch.sh
```

---

## Task 2: Update recipe-manager-demo prompts

**Files:**
- Replace: `prompts/triage.md`, `prompts/implement.md`
- Create: `prompts/CLAUDE.md`, `prompts/adversarial-plan.md`, `prompts/post-impl-review.md`, `prompts/post-impl-retry.md`, `prompts/validate.md`
- Keep unchanged: `prompts/reply.md`, `prompts/review.md` (no upstream changes)
- Repo: `E:/Git/recipe-manager-demo/`
- Source: `E:/git/claude-agent-dispatch/prompts/`

- [ ] **Step 1: Copy updated and new prompt files**

```bash
cp E:/git/claude-agent-dispatch/prompts/triage.md            E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
cp E:/git/claude-agent-dispatch/prompts/implement.md         E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
cp E:/git/claude-agent-dispatch/prompts/CLAUDE.md            E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
cp E:/git/claude-agent-dispatch/prompts/adversarial-plan.md  E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
cp E:/git/claude-agent-dispatch/prompts/post-impl-review.md  E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
cp E:/git/claude-agent-dispatch/prompts/post-impl-retry.md   E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
cp E:/git/claude-agent-dispatch/prompts/validate.md          E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
```

- [ ] **Step 2: Verify prompt count matches upstream**

```bash
ls E:/Git/recipe-manager-demo/.agent-dispatch/prompts/
# Expected: 9 files (CLAUDE.md, adversarial-plan.md, implement.md, post-impl-retry.md,
#           post-impl-review.md, reply.md, review.md, triage.md, validate.md)
```

---

## Task 3: Create .upstream tracking and new workflow for recipe-manager-demo

**Files:**
- Create: `.agent-dispatch/.upstream`
- Modify: `.github/workflows/agent-dispatch.yml` (add `agent-direct-implement` event type)
- Create: `.github/workflows/agent-direct-implement.yml`
- Repo: `E:/Git/recipe-manager-demo/`

- [ ] **Step 1: Create .upstream tracking file**

Generate SHA-256 checksums for all synced files and write the `.upstream` file:

```
repo: https://github.com/jnurre64/claude-agent-dispatch.git
version: <current-upstream-HEAD-sha>
synced_at: "2026-04-13T<timestamp>"
checksums:
  scripts/agent-dispatch.sh: "sha256:<hash>"
  scripts/lib/common.sh: "sha256:<hash>"
  ... (all synced files)
config_vars:
  - AGENT_BOT_USER
  - AGENT_MAX_TURNS
  - AGENT_TIMEOUT
  - AGENT_CIRCUIT_BREAKER_LIMIT
  - AGENT_TEST_COMMAND
  - AGENT_EXTRA_TOOLS
  - AGENT_NOTIFY_BACKEND
  - AGENT_NOTIFY_LEVEL
  - AGENT_NOTIFY_DISCORD_WEBHOOK
  - AGENT_NOTIFY_DISCORD_THREAD_ID
  - AGENT_DISCORD_BOT_TOKEN
  - AGENT_DISCORD_CHANNEL_ID
  - AGENT_DISCORD_GUILD_ID
  - AGENT_DISCORD_ALLOWED_USERS
  - AGENT_DISCORD_ALLOWED_ROLE
  - AGENT_DISCORD_BOT_PORT
  - AGENT_MODEL
  - AGENT_MODEL_TRIAGE
  - AGENT_MODEL_IMPLEMENT
  - AGENT_MODEL_REVIEW
  - AGENT_MODEL_ADVERSARIAL_PLAN
  - AGENT_MODEL_POST_IMPL_REVIEW
  - AGENT_MODEL_POST_IMPL_RETRY
  - AGENT_ALLOW_DIRECT_IMPLEMENT
  - AGENT_ADVERSARIAL_PLAN_REVIEW
  - AGENT_POST_IMPL_REVIEW
  - AGENT_POST_IMPL_REVIEW_MAX_RETRIES
```

- [ ] **Step 2: Add `agent-direct-implement` to repository_dispatch workflow**

In `.github/workflows/agent-dispatch.yml`, add the new event type and job:

```yaml
on:
  repository_dispatch:
    types: [agent-triage, agent-implement, agent-reply, agent-direct-implement]
```

Add a new job block for `direct-implement`:

```yaml
  direct-implement:
    if: github.event.action == 'agent-direct-implement'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (direct implement)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            direct_implement \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"
```

- [ ] **Step 3: Create agent-direct-implement.yml workflow**

New workflow file `.github/workflows/agent-direct-implement.yml`:

```yaml
name: "Claude Agent: Direct Implement"

on:
  issues:
    types: [labeled]

concurrency:
  group: claude-agent-${{ github.event.issue.number }}
  cancel-in-progress: false

jobs:
  direct-implement:
    if: >-
      github.event.label.name == 'agent:implement' &&
      github.actor != 'pennyworth-bot'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            direct_implement \
            "${{ github.repository }}" \
            "${{ github.event.issue.number }}"
```

- [ ] **Step 4: Create new labels on GitHub**

```bash
gh label create "agent:implement" --description "Skip triage, implement directly" --color "5319E7" --repo Frightful-Games/recipe-manager-demo
gh label create "agent:validating" --description "Post-implementation review in progress" --color "BFD4F2" --repo Frightful-Games/recipe-manager-demo
```

- [ ] **Step 5: Commit all changes directly to main**

```bash
cd E:/Git/recipe-manager-demo
git add .agent-dispatch/ .github/workflows/
git commit -m "chore: update agent-dispatch to upstream $(git -C E:/git/claude-agent-dispatch rev-parse --short HEAD)

Syncs all scripts, prompts, and workflows from claude-agent-dispatch.
Adds: review gates, direct implement, per-workflow models, config-vars tracking.
Creates .upstream file for future /update compatibility."
```

---

## Task 4: Update dodge-the-creeps-demo (same as Tasks 1-3)

**Files:** Same as Tasks 1-3 but targeting `E:/Git/dodge-the-creeps-demo/`

- [ ] **Step 1: Copy all script files from upstream**

Same cp commands as Task 1, replacing `recipe-manager-demo` with `dodge-the-creeps-demo`.

- [ ] **Step 2: Verify config.defaults.env is preserved**

Must still contain:
```
AGENT_EXTRA_TOOLS="Bash(godot:*),Bash(Godot:*)"
```
And must NOT contain `AGENT_TEST_COMMAND` (this project doesn't have tests).

- [ ] **Step 3: Copy updated and new prompt files**

Same cp commands as Task 2, targeting `dodge-the-creeps-demo`.

- [ ] **Step 4: Create .upstream tracking file**

Same structure as Task 3 Step 1, targeting `dodge-the-creeps-demo`.

- [ ] **Step 5: Add agent-direct-implement to repository_dispatch workflow and create new workflow**

Same as Task 3 Steps 2-3, targeting `dodge-the-creeps-demo`.

- [ ] **Step 6: Create new labels on GitHub**

```bash
gh label create "agent:implement" --description "Skip triage, implement directly" --color "5319E7" --repo Frightful-Games/dodge-the-creeps-demo
gh label create "agent:validating" --description "Post-implementation review in progress" --color "BFD4F2" --repo Frightful-Games/dodge-the-creeps-demo
```

- [ ] **Step 7: Commit all changes directly to main**

Same commit message pattern as Task 3 Step 5, targeting `dodge-the-creeps-demo`.

---

## Task 5: Write runner update plan document

**Files:**
- Create: `E:/git/claude-agent-dispatch/docs/runner-update-plan-phase1.md`

This document will be committed to the dispatch repo so a separate Claude session on the runner can follow it.

- [ ] **Step 1: Write the runner update plan**

The document must cover:
1. Pulling latest `main` from claude-agent-dispatch on the runner
2. Reinstalling the `shared/dispatch_bot` package (editable install changed)
3. Restarting the discord-bot systemd service
4. Verifying the bot connects and responds to HTTP health checks
5. Checking journalctl logs for import errors (the key Phase 1 risk — discord-bot now imports from `shared/dispatch_bot` instead of having code inline)

Key verification steps:
- `curl -s http://127.0.0.1:8675/health` (if health endpoint exists) or check port is listening
- `journalctl --user -u agent-dispatch-bot --since "5 min ago"` for errors
- Python import check: `cd discord-bot && .venv/bin/python -c "from dispatch_bot import events, github, auth, sanitize, http_listener; print('OK')"`

- [ ] **Step 2: Commit the document**

```bash
cd E:/git/claude-agent-dispatch
git add docs/runner-update-plan-phase1.md
git commit -m "docs: runner update plan for Phase 1 Discord bot checkpoint"
```

---

## Task 6: Update issue #19 with dual-channel scope

**Files:** None (GitHub issue update only)

- [ ] **Step 1: Add dual-channel comment to issue #19**

The current issue explicitly lists "Dual-backend mode" under "Future Enhancements (Out of Scope)." We need to move it into scope.

Post a comment on issue #19 that:
1. Notes that dual-channel support (notifying both Discord and Slack simultaneously) is now a requirement
2. Proposes the design: change `AGENT_NOTIFY_BACKEND` to accept comma-separated values (e.g., `"bot,slack"`)
3. The `notify()` function loops over backends and sends to each independently
4. Each backend's failure is independent (Slack failure doesn't block Discord delivery)
5. Fallback behavior per-backend is preserved (bot fails → webhook fallback for that platform only)
6. This should be implemented in Phase 3 (notification routing) alongside the Slack backend wiring

Implementation is minimal: ~10 lines changed in `notify()` to split on comma and loop.

```bash
gh issue comment 19 --repo jnurre64/claude-agent-dispatch --body "## Scope Update: Dual-Channel Notification Support

Moving **dual-backend mode** from \"Future Enhancements (Out of Scope)\" into Phase 3 scope.

### Requirement
\`AGENT_NOTIFY_BACKEND\` should accept comma-separated values to send notifications to multiple platforms simultaneously:
\`\`\`bash
AGENT_NOTIFY_BACKEND=\"bot,slack\"  # notify both Discord bot and Slack bot
\`\`\`

### Design
- \`notify()\` splits \`AGENT_NOTIFY_BACKEND\` on commas and iterates over each backend
- Each backend sends independently — one failure doesn't block the other
- Per-backend fallback is preserved (e.g., Discord bot down → Discord webhook fallback)
- Single-backend configs continue to work unchanged (no breaking change)

### Implementation
~10 lines in \`scripts/lib/notify.sh\`: replace the current if/else routing with a for loop over backends. This fits naturally into Phase 3 (notification routing) alongside Slack wiring.

### Test Scenarios
- \`AGENT_NOTIFY_BACKEND=\"bot\"\` — existing behavior, unchanged
- \`AGENT_NOTIFY_BACKEND=\"slack\"\` — Slack only
- \`AGENT_NOTIFY_BACKEND=\"bot,slack\"\` — both, Discord failure doesn't block Slack
- \`AGENT_NOTIFY_BACKEND=\"webhook\"\` — legacy webhook mode, unchanged"
```

---

## Task 7: Create test issues in recipe-manager-demo

**Files:** None (GitHub issue creation only)
**Repo:** `Frightful-Games/recipe-manager-demo`

These test issues exercise specific dispatch notification paths to verify the Discord bot is working after the Phase 1 shared package extraction.

- [ ] **Step 1: Create test issue — full triage-to-PR flow**

Tests: `plan_posted` notification, `pr_created` notification, Discord bot buttons (Approve, View)

```bash
gh issue create --repo Frightful-Games/recipe-manager-demo \
  --title "Add recipe prep time field" \
  --label "agent" \
  --body "## Description
Add a \"Prep Time\" field to the Recipe model, displayed on the recipe detail page and recipe list.

## Requirements
- Add \`PrepTimeMinutes\` (int, nullable) property to the \`Recipe\` model
- Display prep time on the recipe detail page (e.g., \"Prep: 30 min\")
- Show prep time in the recipe list cards
- If prep time is null/0, don't display anything (graceful absence)
- Add a prep time input field to the Create and Edit forms
- Add unit tests for the new model property

## Acceptance Criteria
- \`dotnet test\` passes
- Prep time shows on detail and list pages
- Null/zero prep time is handled gracefully"
```

- [ ] **Step 2: Create test issue — needs-info flow**

Tests: `questions_asked` notification, Discord bot "Comment" button, `agent:needs-info` → reply cycle

```bash
gh issue create --repo Frightful-Games/recipe-manager-demo \
  --title "Improve recipe search" \
  --label "agent" \
  --body "## Description
The search feature needs improvement. Users have complained it's not finding what they expect.

## Requirements
- Make search better
- It should find more things"
```

This issue is intentionally vague — the agent should ask clarifying questions, triggering the needs-info notification flow.

- [ ] **Step 3: Create test issue — direct implement flow (if new workflow is ready)**

Tests: `agent:implement` label trigger, `validate.md` prompt, direct implementation without triage

```bash
gh issue create --repo Frightful-Games/recipe-manager-demo \
  --title "Add character count to recipe description field" \
  --body "## Description
Show a live character count below the description textarea on Create and Edit recipe pages.

## Implementation Plan
1. Add a \`<span id=\"char-count\">\` below the description textarea
2. Add inline JavaScript: on \`input\` event, update the span with \`textarea.value.length\`
3. Style: gray text, small font, right-aligned

No model changes. No backend changes. Pure frontend."
```

This one gets the `agent:implement` label instead of `agent` — it has its own plan already.

---

## Task 8: Create test issues in dodge-the-creeps-demo

**Files:** None (GitHub issue creation only)
**Repo:** `Frightful-Games/dodge-the-creeps-demo`

- [ ] **Step 1: Create test issue — full triage-to-PR flow**

Tests: `plan_posted` notification, `pr_created` notification, Discord bot buttons

```bash
gh issue create --repo Frightful-Games/dodge-the-creeps-demo \
  --title "Add score multiplier for consecutive dodges" \
  --label "agent" \
  --body "## Description
Add a score multiplier that increases when the player survives without getting hit for consecutive time intervals.

## Requirements
- After every 10 seconds of survival, increment a multiplier (starts at 1x, increases to 2x, 3x, etc., capped at 5x)
- Display the current multiplier on the HUD next to the score
- The multiplier resets if the player gets hit (game over resets everything anyway)
- Score points earned during higher multipliers are multiplied accordingly
- Show a brief visual indicator when the multiplier increases (e.g., flash the multiplier text)

## Acceptance Criteria
- Multiplier increments every 10 seconds
- HUD shows current multiplier
- Score calculation uses the multiplier
- Multiplier caps at 5x"
```

- [ ] **Step 2: Create test issue — needs-info flow**

Tests: `questions_asked` notification, Discord bot interaction for replying

```bash
gh issue create --repo Frightful-Games/dodge-the-creeps-demo \
  --title "Add a new enemy type" \
  --label "agent" \
  --body "## Description
We need a new enemy type to make the game more interesting."
```

Intentionally vague to trigger clarification questions.

---

## Execution Notes

- **Tasks 1-4** (both demo repo updates) can be parallelized — they're independent repos
- **Task 5** (runner plan) can be done in parallel with Tasks 1-4
- **Task 6** (issue #19 update) is independent of all other tasks
- **Tasks 7-8** (test issues) depend on Tasks 1-4 being committed and pushed, since the runner needs the updated scripts
- **Tasks 7-8** also depend on the runner being updated (Task 5 executed on the runner) if we want Discord notifications to actually work

### Verification Checklist (after runner is updated and test issues are created)

For each test issue, verify in the Discord channel:
- [ ] Triage notification appears with plan embed + Approve/Request Changes buttons
- [ ] Clicking "Approve" adds `agent:plan-approved` label and triggers implementation
- [ ] Implementation completion sends `pr_created` notification with View PR button
- [ ] Needs-info issue sends `questions_asked` notification with Comment button
- [ ] Clicking "Comment" opens modal, submitting posts to GitHub and triggers reply dispatch
