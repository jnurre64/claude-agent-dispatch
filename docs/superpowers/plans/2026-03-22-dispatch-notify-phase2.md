# Dispatch Notify Phase 2: Discord Bot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the send-only Discord webhook with an interactive bot that adds buttons, slash commands, and modals for two-way interaction between Discord and GitHub.

**Architecture:** A single-file Python bot (~200 lines) using `discord.py` connects to Discord via gateway WebSocket. An `aiohttp` HTTP listener on localhost receives POSTs from the existing `notify()` shell function, formats embeds with interactive buttons, and sends them to Discord. Button clicks and slash commands are translated to `gh` CLI calls. The existing `notify.sh` gains a backend toggle (`AGENT_NOTIFY_BACKEND`) to route notifications to the bot's local API instead of the Discord webhook directly.

**Tech Stack:** Python 3.10+, discord.py 2.x, aiohttp, pytest, BATS (for shell changes)

**Spec:** `docs/superpowers/specs/2026-03-22-dispatch-notify-design.md`

---

## File Structure

```
discord-bot/                          # NEW directory
  bot.py                              # Main bot: HTTP listener, Discord sender, interactions, GitHub bridge
  requirements.txt                    # discord.py, aiohttp
  install.sh                          # Creates venv, installs deps, registers systemd service
  agent-dispatch-bot.service          # systemd unit file (template)
  README.md                           # Setup guide
  tests/
    conftest.py                       # Shared fixtures (mock Discord client, mock gh)
    test_utils.py                     # Tests for pure utility functions
    test_embeds.py                    # Tests for embed/button construction
    test_http.py                      # Tests for the local HTTP endpoint
    test_interactions.py              # Tests for button/modal/slash command handlers

scripts/lib/notify.sh                 # MODIFY: add bot backend routing
scripts/lib/defaults.sh               # MODIFY: add Phase 2 config defaults
config.env.example                    # MODIFY: document Phase 2 vars
docs/notifications.md                 # MODIFY: add Phase 2 setup instructions
tests/test_notify.bats                # MODIFY: add bot backend tests
```

---

### Task 1: Configuration Defaults and Shell-Side Backend Routing

Add Phase 2 config variables and modify `notify()` to route to the bot's local HTTP API when configured.

**Files:**
- Modify: `scripts/lib/defaults.sh:59-67`
- Modify: `config.env.example:52-62`
- Modify: `scripts/lib/notify.sh:133-173`
- Test: `tests/test_notify.bats`

- [ ] **Step 1: Write BATS tests for new config defaults**

Append to `tests/test_notify.bats`:

```bash
# ===================================================================
# Phase 2: Configuration defaults
# ===================================================================

@test "defaults: AGENT_DISCORD_BOT_TOKEN defaults to empty" {
    export AGENT_BOT_USER="test-bot"
    unset AGENT_DISCORD_BOT_TOKEN

    source "${LIB_DIR}/defaults.sh"

    assert_equal "$AGENT_DISCORD_BOT_TOKEN" ""
}

@test "defaults: AGENT_DISCORD_CHANNEL_ID defaults to empty" {
    export AGENT_BOT_USER="test-bot"
    unset AGENT_DISCORD_CHANNEL_ID

    source "${LIB_DIR}/defaults.sh"

    assert_equal "$AGENT_DISCORD_CHANNEL_ID" ""
}

@test "defaults: AGENT_DISCORD_BOT_PORT defaults to 8675" {
    export AGENT_BOT_USER="test-bot"
    unset AGENT_DISCORD_BOT_PORT

    source "${LIB_DIR}/defaults.sh"

    assert_equal "$AGENT_DISCORD_BOT_PORT" "8675"
}

@test "defaults: AGENT_NOTIFY_BACKEND defaults to webhook" {
    export AGENT_BOT_USER="test-bot"
    unset AGENT_NOTIFY_BACKEND

    source "${LIB_DIR}/defaults.sh"

    assert_equal "$AGENT_NOTIFY_BACKEND" "webhook"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/claude-agent-dispatch && ./tests/bats/bin/bats tests/test_notify.bats`
Expected: FAIL — variables not yet defined in defaults.sh

- [ ] **Step 3: Add Phase 2 defaults to defaults.sh**

Append after the existing notification block (after line 67) in `scripts/lib/defaults.sh`:

```bash
# ─── Discord Bot (Phase 2 — interactive notifications) ────────────
AGENT_DISCORD_BOT_TOKEN="${AGENT_DISCORD_BOT_TOKEN:-}"
AGENT_DISCORD_CHANNEL_ID="${AGENT_DISCORD_CHANNEL_ID:-}"
AGENT_DISCORD_GUILD_ID="${AGENT_DISCORD_GUILD_ID:-}"
AGENT_DISCORD_ALLOWED_USERS="${AGENT_DISCORD_ALLOWED_USERS:-}"
AGENT_DISCORD_ALLOWED_ROLE="${AGENT_DISCORD_ALLOWED_ROLE:-}"
AGENT_DISCORD_BOT_PORT="${AGENT_DISCORD_BOT_PORT:-8675}"
AGENT_NOTIFY_BACKEND="${AGENT_NOTIFY_BACKEND:-webhook}"
AGENT_DISPATCH_REPO="${AGENT_DISPATCH_REPO:-}"
```

- [ ] **Step 4: Run tests to verify defaults pass**

Run: `cd ~/claude-agent-dispatch && ./tests/bats/bin/bats tests/test_notify.bats`
Expected: All tests PASS

- [ ] **Step 5: Write BATS tests for bot backend routing in notify.sh**

Append to `tests/test_notify.bats`:

```bash
# ===================================================================
# Phase 2: Bot backend routing
# ===================================================================

@test "notify: routes to bot HTTP API when AGENT_NOTIFY_BACKEND=bot" {
    export AGENT_NOTIFY_DISCORD_WEBHOOK="https://discord.com/api/webhooks/123/abc"
    export AGENT_NOTIFY_BACKEND="bot"
    export AGENT_DISCORD_BOT_PORT="8675"
    export AGENT_NOTIFY_LEVEL="all"
    create_mock "curl" ""
    _source_notify

    run notify "plan_posted" "Test Issue" "https://github.com/test/1" "Plan summary"
    assert_success

    local calls
    calls=$(get_mock_calls "curl")
    echo "$calls" | grep -q "127.0.0.1:8675/notify"
}

@test "notify: bot backend sends JSON with issue_number and repo" {
    export AGENT_NOTIFY_DISCORD_WEBHOOK="https://discord.com/api/webhooks/123/abc"
    export AGENT_NOTIFY_BACKEND="bot"
    export AGENT_DISCORD_BOT_PORT="8675"
    export AGENT_NOTIFY_LEVEL="all"
    # Use a mock that captures the -d argument
    create_mock "curl" ""
    _source_notify

    run notify "plan_posted" "Test Issue" "https://github.com/test/1" "Plan summary"
    assert_success

    local calls
    calls=$(get_mock_calls "curl")
    echo "$calls" | grep -q "issue_number"
    echo "$calls" | grep -q "event_type"
}

@test "notify: falls back to webhook when bot backend curl fails" {
    export AGENT_NOTIFY_DISCORD_WEBHOOK="https://discord.com/api/webhooks/123/abc"
    export AGENT_NOTIFY_BACKEND="bot"
    export AGENT_DISCORD_BOT_PORT="8675"
    export AGENT_NOTIFY_LEVEL="all"
    _source_notify

    # Create a curl mock that fails on localhost but succeeds otherwise
    local mock_bin="${TEST_TEMP_DIR}/bin"
    mkdir -p "$mock_bin"
    cat > "${mock_bin}/curl" << 'MOCK'
#!/bin/bash
echo "$@" >> "${TEST_TEMP_DIR}/mock_calls_curl"
if echo "$@" | grep -q "127.0.0.1"; then
    exit 1
fi
exit 0
MOCK
    chmod +x "${mock_bin}/curl"
    export PATH="${mock_bin}:${PATH}"

    run notify "plan_posted" "Test Issue" "https://github.com/test/1" "Plan summary"
    assert_success

    local calls
    calls=$(get_mock_calls "curl")
    # Should have two calls: first to bot (failed), then fallback to webhook
    local call_count
    call_count=$(echo "$calls" | wc -l)
    [ "$call_count" -eq 2 ]
    echo "$calls" | tail -1 | grep -q "discord.com/api/webhooks"
}

@test "notify: webhook backend still works unchanged" {
    export AGENT_NOTIFY_DISCORD_WEBHOOK="https://discord.com/api/webhooks/123/abc"
    export AGENT_NOTIFY_BACKEND="webhook"
    export AGENT_NOTIFY_LEVEL="all"
    create_mock "curl" ""
    _source_notify

    run notify "plan_posted" "Test Issue" "https://github.com/test/1" "Plan summary"
    assert_success

    local calls
    calls=$(get_mock_calls "curl")
    echo "$calls" | grep -q "discord.com/api/webhooks"
    ! echo "$calls" | grep -q "127.0.0.1"
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `cd ~/claude-agent-dispatch && ./tests/bats/bin/bats tests/test_notify.bats`
Expected: FAIL — notify() doesn't handle bot backend yet

- [ ] **Step 7: Implement bot backend routing in notify.sh**

Replace everything from the "Main notification function" comment through end of file in `scripts/lib/notify.sh` (lines 133-173) with:

```bash
# ─── Send to bot local HTTP API ──────────────────────────────────
# Usage: _notify_send_bot <event_type> <title> <url> <description>
# Returns 0 on success, 1 on failure (caller should fallback)
_notify_send_bot() {
    local event_type="$1"
    local title="$2"
    local url="$3"
    local description="$4"
    local port="${AGENT_DISCORD_BOT_PORT:-8675}"

    local json
    json=$(jq -n \
        --arg event_type "$event_type" \
        --arg title "$title" \
        --arg url "$url" \
        --arg description "$description" \
        --arg issue_number "${NUMBER:-0}" \
        --arg repo "${REPO:-}" \
        '{
            event_type: $event_type,
            title: $title,
            url: $url,
            description: $description,
            issue_number: ($issue_number | tonumber),
            repo: $repo
        }')

    curl -sf -o /dev/null -X POST "http://127.0.0.1:${port}/notify" \
        -H "Content-Type: application/json" \
        -d "$json" 2>/dev/null
}

# ─── Main notification function ────────────────────────────────────
# Usage: notify <event_type> <title> <url> [description]
notify() {
    local event_type="${1:-}"
    local title="${2:-}"
    local url="${3:-}"
    local description="${4:-}"

    # No-op if no platform is configured
    if [ -z "${AGENT_NOTIFY_DISCORD_WEBHOOK:-}" ]; then
        return 0
    fi

    # Check notification level filter
    _notify_should_send "$event_type" || return 0

    # ── Route based on backend ──
    local backend="${AGENT_NOTIFY_BACKEND:-webhook}"

    if [ "$backend" = "bot" ]; then
        # Try bot first, fall back to webhook on failure
        if ! _notify_send_bot "$event_type" "$title" "$url" "$description"; then
            local discord_json
            discord_json=$(_notify_build_discord_embed "$event_type" "$title" "$url" "$description")
            _notify_send_discord "$discord_json"
        fi
    else
        # Webhook mode (Phase 1 default)
        local discord_json
        discord_json=$(_notify_build_discord_embed "$event_type" "$title" "$url" "$description")
        _notify_send_discord "$discord_json"
    fi
}
```

- [ ] **Step 8: Run all tests to verify they pass**

Run: `cd ~/claude-agent-dispatch && ./tests/bats/bin/bats tests/test_notify.bats`
Expected: All tests PASS

- [ ] **Step 9: Update config.env.example with Phase 2 variables**

Append to `config.env.example` after the existing notification section:

```bash
# ── Discord Bot (Phase 2 — interactive notifications) ────────────
# Enables buttons, slash commands, and modals for two-way interaction.
# Set AGENT_NOTIFY_BACKEND="bot" to activate. Requires a Discord bot application.
# See discord-bot/README.md for setup instructions.

# Discord bot token (from Discord Developer Portal > Bot > Token)
# AGENT_DISCORD_BOT_TOKEN=""

# Discord channel ID for notifications (right-click channel > Copy Channel ID)
# AGENT_DISCORD_CHANNEL_ID=""

# Discord guild (server) ID for slash command registration
# AGENT_DISCORD_GUILD_ID=""

# Comma-separated Discord user IDs allowed to click action buttons
# AGENT_DISCORD_ALLOWED_USERS=""

# Or a Discord role ID (members of this role can click action buttons)
# AGENT_DISCORD_ALLOWED_ROLE=""

# Local HTTP port for dispatch -> bot communication (default: 8675)
# AGENT_DISCORD_BOT_PORT="8675"

# Backend: "webhook" (Phase 1, default) or "bot" (Phase 2, interactive)
# AGENT_NOTIFY_BACKEND="webhook"

# GitHub repository for the bot to operate on (owner/repo format)
# Required when AGENT_NOTIFY_BACKEND="bot" — used for gh CLI calls from Discord
# AGENT_DISPATCH_REPO="owner/repo"
```

- [ ] **Step 10: Run shellcheck and commit**

Run: `shellcheck scripts/lib/notify.sh scripts/lib/defaults.sh`
Expected: No warnings

```bash
git add scripts/lib/defaults.sh scripts/lib/notify.sh config.env.example tests/test_notify.bats
git commit -m "feat(notify): add Phase 2 config defaults and bot backend routing

notify() now supports AGENT_NOTIFY_BACKEND=bot which POSTs to the local
Discord bot HTTP API. Falls back to webhook if the bot is unreachable.
New config vars for bot token, channel, guild, permissions, and port."
```

---

### Task 2: Bot Project Scaffold and Utility Functions

Create the `discord-bot/` directory with dependencies and TDD the pure utility functions (sanitize_input, custom_id parsing, authorization check).

**Files:**
- Create: `discord-bot/requirements.txt`
- Create: `discord-bot/tests/conftest.py`
- Create: `discord-bot/tests/test_utils.py`
- Create: `discord-bot/bot.py` (partial — utility functions only)

- [ ] **Step 1: Create requirements.txt**

```
discord.py>=2.3,<3
aiohttp>=3.9,<4
```

- [ ] **Step 2: Create the venv and install dependencies**

```bash
cd ~/claude-agent-dispatch/discord-bot
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install pytest pytest-asyncio
```

- [ ] **Step 3: Write test fixtures in conftest.py**

Create `discord-bot/tests/conftest.py`:

```python
import os
import sys

import pytest

# Add parent directory to path so we can import bot
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
```

- [ ] **Step 4: Write failing tests for utility functions**

Create `discord-bot/tests/test_utils.py`:

```python
from bot import sanitize_input, parse_custom_id, is_authorized_check


class TestSanitizeInput:
    def test_passes_normal_text(self):
        assert sanitize_input("Please fix the login bug") == "Please fix the login bug"

    def test_removes_backticks(self):
        assert "`" not in sanitize_input("use `rm -rf /`")

    def test_removes_dollar_signs(self):
        assert "$" not in sanitize_input("cost is $100 $(whoami)")

    def test_removes_backslashes(self):
        assert "\\" not in sanitize_input("path\\to\\file")

    def test_truncates_to_2000_chars(self):
        long_text = "x" * 3000
        result = sanitize_input(long_text)
        assert len(result) == 2000

    def test_preserves_markdown_formatting(self):
        text = "**bold** and *italic* and [link](url)"
        assert sanitize_input(text) == text

    def test_preserves_newlines(self):
        text = "line1\nline2\nline3"
        assert sanitize_input(text) == text

    def test_empty_string(self):
        assert sanitize_input("") == ""


class TestParseCustomId:
    def test_approve(self):
        action, issue = parse_custom_id("approve:42")
        assert action == "approve"
        assert issue == 42

    def test_changes(self):
        action, issue = parse_custom_id("changes:7")
        assert action == "changes"
        assert issue == 7

    def test_comment(self):
        action, issue = parse_custom_id("comment:123")
        assert action == "comment"
        assert issue == 123

    def test_retry(self):
        action, issue = parse_custom_id("retry:1")
        assert action == "retry"
        assert issue == 1

    def test_invalid_no_colon(self):
        action, issue = parse_custom_id("invalid")
        assert action is None
        assert issue is None

    def test_invalid_non_numeric(self):
        action, issue = parse_custom_id("approve:abc")
        assert action is None
        assert issue is None


class TestIsAuthorizedCheck:
    def test_user_in_allowed_list(self):
        assert is_authorized_check(
            user_id="123", role_ids=[], allowed_users={"123", "456"}, allowed_role=""
        )

    def test_user_not_in_allowed_list(self):
        assert not is_authorized_check(
            user_id="789", role_ids=[], allowed_users={"123", "456"}, allowed_role=""
        )

    def test_user_has_allowed_role(self):
        assert is_authorized_check(
            user_id="789", role_ids=["100", "200"], allowed_users=set(), allowed_role="200"
        )

    def test_user_lacks_allowed_role(self):
        assert not is_authorized_check(
            user_id="789", role_ids=["100"], allowed_users=set(), allowed_role="200"
        )

    def test_no_restrictions_configured(self):
        # If no users or role configured, deny all (secure by default)
        assert not is_authorized_check(
            user_id="123", role_ids=[], allowed_users=set(), allowed_role=""
        )

    def test_user_id_or_role_either_works(self):
        assert is_authorized_check(
            user_id="123", role_ids=["999"], allowed_users={"123"}, allowed_role="888"
        )
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_utils.py -v`
Expected: FAIL — bot.py doesn't exist yet

- [ ] **Step 6: Implement utility functions in bot.py**

Create `discord-bot/bot.py` (initial version — utility functions only, main bot code added in later tasks):

```python
"""Discord bot for claude-agent-dispatch interactive notifications."""

import logging
import os
import re

log = logging.getLogger("dispatch-bot")

# --- Configuration (from environment) ---
BOT_TOKEN = os.environ.get("AGENT_DISCORD_BOT_TOKEN", "")
CHANNEL_ID = int(os.environ.get("AGENT_DISCORD_CHANNEL_ID", "0"))
GUILD_ID = int(os.environ.get("AGENT_DISCORD_GUILD_ID", "0"))
ALLOWED_USERS = set(os.environ.get("AGENT_DISCORD_ALLOWED_USERS", "").split(",")) - {""}
ALLOWED_ROLE = os.environ.get("AGENT_DISCORD_ALLOWED_ROLE", "")
BOT_PORT = int(os.environ.get("AGENT_DISCORD_BOT_PORT", "8675"))
REPO = os.environ.get("AGENT_DISPATCH_REPO", "")


def sanitize_input(text: str) -> str:
    """Remove shell-dangerous characters from user input."""
    return re.sub(r"[`$\\]", "", text)[:2000]


def parse_custom_id(custom_id: str) -> tuple[str | None, int | None]:
    """Parse 'action:issue_number' from a button custom_id."""
    if ":" not in custom_id:
        return None, None
    action, num_str = custom_id.split(":", 1)
    try:
        return action, int(num_str)
    except ValueError:
        return None, None


def is_authorized_check(
    user_id: str, role_ids: list[str], allowed_users: set[str], allowed_role: str
) -> bool:
    """Check if a user is authorized to perform bot actions."""
    if not allowed_users and not allowed_role:
        return False
    if user_id in allowed_users:
        return True
    if allowed_role and allowed_role in role_ids:
        return True
    return False
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_utils.py -v`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add discord-bot/requirements.txt discord-bot/bot.py discord-bot/tests/
git commit -m "feat(bot): scaffold discord bot with tested utility functions

Pure functions for input sanitization, custom_id parsing, and
authorization checking. All TDD with pytest."
```

---

### Task 3: Embed and Button Construction

TDD the Discord embed builder and button view factory.

**Files:**
- Create: `discord-bot/tests/test_embeds.py`
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Write failing tests for embed and button construction**

Create `discord-bot/tests/test_embeds.py`:

```python
import discord

from bot import build_embed, build_buttons, EVENT_COLORS, EVENT_LABELS, EVENT_INDICATORS


class TestBuildEmbed:
    def test_plan_posted_has_blue_color(self):
        embed = build_embed("plan_posted", "Add caching", "https://github.com/r/1", "Plan here", 42, "org/repo")
        assert embed.color.value == 0x3498DB

    def test_tests_failed_has_red_color(self):
        embed = build_embed("tests_failed", "Fix bug", "https://github.com/r/1", "Failed", 5, "org/repo")
        assert embed.color.value == 0xED4245

    def test_pr_created_has_green_color(self):
        embed = build_embed("pr_created", "Feature X", "https://github.com/r/1", "3 commits", 10, "org/repo")
        assert embed.color.value == 0x57F287

    def test_title_includes_indicator_and_issue_number(self):
        embed = build_embed("plan_posted", "My Issue", "https://example.com", "desc", 42, "org/repo")
        assert "#42" in embed.title
        assert "Plan Ready" in embed.title

    def test_footer_includes_automation_disclosure(self):
        embed = build_embed("plan_posted", "Title", "https://example.com", "desc", 1, "org/repo")
        assert "Automated by claude-agent-dispatch" in embed.footer.text

    def test_footer_includes_repo_and_issue(self):
        embed = build_embed("plan_posted", "Title", "https://example.com", "desc", 42, "org/repo")
        assert "org/repo #42" in embed.footer.text

    def test_description_truncated_at_4000(self):
        long_desc = "x" * 5000
        embed = build_embed("plan_posted", "Title", "https://example.com", long_desc, 1, "r")
        assert len(embed.description) <= 4000

    def test_url_set(self):
        embed = build_embed("plan_posted", "Title", "https://example.com/42", "d", 42, "r")
        assert embed.url == "https://example.com/42"

    def test_unknown_event_gets_grey_color(self):
        embed = build_embed("unknown_event", "Title", "https://example.com", "d", 1, "r")
        assert embed.color.value == 0x95A5A6


class TestBuildButtons:
    def test_plan_posted_has_approve_changes_comment(self):
        view = build_buttons("plan_posted", 42, "https://example.com")
        labels = [child.label for child in view.children]
        assert "Approve" in labels
        assert "Request Changes" in labels
        assert "Comment" in labels

    def test_plan_posted_has_view_link(self):
        view = build_buttons("plan_posted", 42, "https://example.com")
        link_buttons = [c for c in view.children if c.url]
        assert len(link_buttons) >= 1
        assert link_buttons[0].url == "https://example.com"

    def test_agent_failed_has_retry(self):
        view = build_buttons("agent_failed", 42, "https://example.com")
        labels = [child.label for child in view.children]
        assert "Retry" in labels

    def test_agent_failed_no_approve(self):
        view = build_buttons("agent_failed", 42, "https://example.com")
        labels = [child.label for child in view.children]
        assert "Approve" not in labels

    def test_tests_passed_view_only(self):
        view = build_buttons("tests_passed", 42, "https://example.com")
        action_buttons = [c for c in view.children if not c.url]
        assert len(action_buttons) == 0

    def test_custom_ids_encode_issue_number(self):
        view = build_buttons("plan_posted", 99, "https://example.com")
        custom_ids = [c.custom_id for c in view.children if c.custom_id]
        assert "approve:99" in custom_ids
        assert "changes:99" in custom_ids
        assert "comment:99" in custom_ids

    def test_review_feedback_has_view_only(self):
        view = build_buttons("review_feedback", 42, "https://example.com")
        action_buttons = [c for c in view.children if not c.url]
        assert len(action_buttons) == 0

    def test_pr_created_has_view_link(self):
        view = build_buttons("pr_created", 42, "https://example.com/pull/5")
        link_buttons = [c for c in view.children if c.url]
        assert any(b.url == "https://example.com/pull/5" for b in link_buttons)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_embeds.py -v`
Expected: FAIL — functions not yet defined

- [ ] **Step 3: Implement embed and button construction in bot.py**

Add to `discord-bot/bot.py` after the utility functions:

```python
import discord

# --- Event metadata ---
EVENT_COLORS = {
    "pr_created": 0x57F287, "tests_passed": 0x57F287,
    "tests_failed": 0xED4245, "agent_failed": 0xED4245,
    "plan_posted": 0x3498DB, "questions_asked": 0x3498DB,
    "review_feedback": 0xFFFF00,
}

EVENT_LABELS = {
    "plan_posted": "Plan Ready", "questions_asked": "Questions",
    "implement_started": "Implementation Started",
    "tests_passed": "Tests Passed", "tests_failed": "Tests Failed",
    "pr_created": "PR Created", "review_feedback": "Review Feedback",
    "agent_failed": "Agent Failed",
}

EVENT_INDICATORS = {
    "pr_created": "[OK]", "tests_passed": "[OK]",
    "tests_failed": "[FAIL]", "agent_failed": "[FAIL]",
    "plan_posted": "[INFO]", "questions_asked": "[INFO]",
    "review_feedback": "[ACTION]", "implement_started": "[INFO]",
}

# Events that get action buttons (not just a View link)
_PLAN_EVENTS = {"plan_posted"}
_RETRY_EVENTS = {"agent_failed"}


def build_embed(
    event_type: str, title: str, url: str, description: str, issue_number: int, repo: str
) -> discord.Embed:
    """Build a Discord embed for a dispatch notification."""
    indicator = EVENT_INDICATORS.get(event_type, "[INFO]")
    label = EVENT_LABELS.get(event_type, "Agent Update")
    color = EVENT_COLORS.get(event_type, 0x95A5A6)

    embed = discord.Embed(
        title=f"{indicator} {label} -- #{issue_number}: {title}",
        url=url,
        description=description[:4000],
        color=color,
    )
    embed.set_footer(text=f"Automated by claude-agent-dispatch | {repo} #{issue_number}")
    return embed


def build_buttons(event_type: str, issue_number: int, url: str) -> discord.ui.View:
    """Build interactive buttons for a notification message."""
    view = discord.ui.View(timeout=None)
    view.add_item(discord.ui.Button(label="View", url=url, style=discord.ButtonStyle.link))

    if event_type in _PLAN_EVENTS:
        view.add_item(discord.ui.Button(
            label="Approve", custom_id=f"approve:{issue_number}", style=discord.ButtonStyle.success
        ))
        view.add_item(discord.ui.Button(
            label="Request Changes", custom_id=f"changes:{issue_number}", style=discord.ButtonStyle.danger
        ))
        view.add_item(discord.ui.Button(
            label="Comment", custom_id=f"comment:{issue_number}", style=discord.ButtonStyle.secondary
        ))
    elif event_type in _RETRY_EVENTS:
        view.add_item(discord.ui.Button(
            label="Retry", custom_id=f"retry:{issue_number}", style=discord.ButtonStyle.primary
        ))

    return view
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_embeds.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py discord-bot/tests/test_embeds.py
git commit -m "feat(bot): add embed builder and button factory with tests

Color-coded embeds matching Phase 1 webhook format. Plan events get
Approve/Request Changes/Comment buttons. Failed events get Retry."
```

---

### Task 4: Local HTTP Listener and Discord Sender

Add the aiohttp HTTP endpoint that receives POSTs from `notify()` and sends embeds with buttons to Discord.

**Files:**
- Create: `discord-bot/tests/test_http.py`
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Write failing tests for the HTTP handler**

Create `discord-bot/tests/test_http.py`:

```python
import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from bot import create_notify_handler


@pytest.fixture
def mock_channel():
    channel = AsyncMock()
    channel.send = AsyncMock()
    return channel


@pytest.fixture
def handler(mock_channel):
    return create_notify_handler(mock_channel)


@pytest.fixture
def make_request():
    def _make(data: dict):
        request = AsyncMock()
        request.json = AsyncMock(return_value=data)
        return request
    return _make


VALID_PAYLOAD = {
    "event_type": "plan_posted",
    "title": "Add caching",
    "url": "https://github.com/org/repo/issues/42",
    "description": "Plan summary here",
    "issue_number": 42,
    "repo": "org/repo",
}


class TestNotifyHandler:
    @pytest.mark.asyncio
    async def test_sends_embed_to_channel(self, handler, mock_channel, make_request):
        request = make_request(VALID_PAYLOAD)
        response = await handler(request)
        assert response.status == 200
        mock_channel.send.assert_called_once()

    @pytest.mark.asyncio
    async def test_embed_has_correct_title(self, handler, mock_channel, make_request):
        request = make_request(VALID_PAYLOAD)
        await handler(request)
        call_kwargs = mock_channel.send.call_args
        embed = call_kwargs.kwargs["embed"]
        assert "#42" in embed.title
        assert "Add caching" in embed.title

    @pytest.mark.asyncio
    async def test_sends_buttons(self, handler, mock_channel, make_request):
        request = make_request(VALID_PAYLOAD)
        await handler(request)
        call_kwargs = mock_channel.send.call_args
        view = call_kwargs.kwargs["view"]
        assert len(view.children) > 1  # View link + action buttons

    @pytest.mark.asyncio
    async def test_returns_503_when_channel_is_none(self, make_request):
        handler = create_notify_handler(None)
        request = make_request(VALID_PAYLOAD)
        response = await handler(request)
        assert response.status == 503

    @pytest.mark.asyncio
    async def test_handles_missing_optional_fields(self, handler, mock_channel, make_request):
        minimal = {"event_type": "tests_passed", "title": "T", "url": "https://x.com", "issue_number": 1, "repo": "r"}
        request = make_request(minimal)
        response = await handler(request)
        assert response.status == 200
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_http.py -v`
Expected: FAIL — `create_notify_handler` not defined

- [ ] **Step 3: Implement the HTTP handler in bot.py**

Add to `discord-bot/bot.py`:

```python
from aiohttp import web


def create_notify_handler(channel):
    """Create an aiohttp handler that sends notifications to the given Discord channel."""
    async def handle_notify(request: web.Request) -> web.Response:
        if channel is None:
            return web.Response(status=503, text="Channel not found")

        data = await request.json()
        event_type = data["event_type"]
        title = data["title"]
        url = data["url"]
        description = data.get("description", "")
        issue_number = data.get("issue_number", 0)
        repo = data.get("repo", "")

        embed = build_embed(event_type, title, url, description, issue_number, repo)
        view = build_buttons(event_type, issue_number, url)
        await channel.send(embed=embed, view=view)
        return web.Response(text="OK")

    return handle_notify
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_http.py -v`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py discord-bot/tests/test_http.py
git commit -m "feat(bot): add local HTTP listener for dispatch notifications

aiohttp handler receives POST from notify.sh, builds embed with
buttons, sends to Discord channel. Returns 503 if channel unavailable."
```

---

### Task 5: GitHub Bridge and Interaction Handlers

TDD the GitHub CLI bridge and button/modal interaction handlers.

**Files:**
- Create: `discord-bot/tests/test_interactions.py`
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Write failing tests for gh_command and button handlers**

Create `discord-bot/tests/test_interactions.py`:

```python
import subprocess
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock

import discord
import pytest

from bot import (
    gh_command,
    handle_button_interaction,
    FeedbackModal,
    ALLOWED_USERS,
    ALLOWED_ROLE,
)


class TestGhCommand:
    @patch("bot.subprocess.run")
    def test_calls_gh_with_args(self, mock_run):
        mock_run.return_value = MagicMock(stdout="ok\n", returncode=0)
        result = gh_command(["issue", "edit", "42", "--repo", "org/repo", "--add-label", "agent"])
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert args[0] == "gh"
        assert "issue" in args
        assert "42" in args

    @patch("bot.subprocess.run")
    def test_returns_stdout_stripped(self, mock_run):
        mock_run.return_value = MagicMock(stdout="  result  \n", returncode=0)
        assert gh_command(["issue", "view", "1"]) == "result"

    @patch("bot.subprocess.run")
    def test_handles_timeout(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="gh", timeout=30)
        result = gh_command(["issue", "view", "1"])
        assert "timed out" in result.lower()

    @patch("bot.subprocess.run")
    def test_handles_error(self, mock_run):
        mock_run.return_value = MagicMock(stdout="", stderr="not found", returncode=1)
        result = gh_command(["issue", "view", "999"])
        # Should not raise, returns stderr or empty
        assert isinstance(result, str)


def _mock_interaction(custom_id: str, user_id: str = "123", role_ids=None, display_name: str = "jonny"):
    """Build a mock Discord interaction for button clicks."""
    interaction = AsyncMock(spec=discord.Interaction)
    interaction.data = {"custom_id": custom_id}
    interaction.user = MagicMock()
    interaction.user.id = int(user_id)
    interaction.user.display_name = display_name
    interaction.user.roles = [MagicMock(id=int(r)) for r in (role_ids or [])]
    interaction.response = AsyncMock()
    interaction.followup = AsyncMock()
    interaction.message = AsyncMock()
    interaction.message.embeds = [discord.Embed(title="Test")]
    interaction.message.components = []
    return interaction


class TestHandleButtonInteraction:
    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_approve_adds_label(self, mock_gh):
        mock_gh.return_value = ""
        interaction = _mock_interaction("approve:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        # Should have called gh to remove plan-review and add plan-approved
        calls = [str(c) for c in mock_gh.call_args_list]
        combined = " ".join(calls)
        assert "plan-approved" in combined

    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_approve_sends_ephemeral_confirmation(self, mock_gh):
        mock_gh.return_value = ""
        interaction = _mock_interaction("approve:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        interaction.followup.send.assert_called_once()

    @pytest.mark.asyncio
    async def test_unauthorized_user_rejected(self):
        interaction = _mock_interaction("approve:42", user_id="999")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.ALLOWED_ROLE", ""):
            await handle_button_interaction(interaction)
        interaction.response.send_message.assert_called_once()
        call_kwargs = interaction.response.send_message.call_args.kwargs
        assert call_kwargs.get("ephemeral") is True

    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_retry_resets_labels(self, mock_gh):
        mock_gh.return_value = ""
        interaction = _mock_interaction("retry:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        mock_gh.assert_called_once()
        call_args = mock_gh.call_args[0][0]
        assert "--remove-label" in call_args
        assert "--add-label" in call_args
        assert "agent" in call_args

    @pytest.mark.asyncio
    async def test_changes_shows_modal(self):
        interaction = _mock_interaction("changes:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}):
            await handle_button_interaction(interaction)
        interaction.response.send_modal.assert_called_once()

    @pytest.mark.asyncio
    async def test_comment_shows_modal(self):
        interaction = _mock_interaction("comment:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}):
            await handle_button_interaction(interaction)
        interaction.response.send_modal.assert_called_once()


class TestFeedbackModal:
    def test_modal_title_for_changes(self):
        modal = FeedbackModal(action="changes", issue_number=42, repo="org/repo")
        assert "Request Changes" in modal.title

    def test_modal_title_for_comment(self):
        modal = FeedbackModal(action="comment", issue_number=42, repo="org/repo")
        assert "Comment" in modal.title

    def test_modal_has_text_input(self):
        modal = FeedbackModal(action="comment", issue_number=42, repo="org/repo")
        # discord.ui.Modal items
        assert len(modal.children) > 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_interactions.py -v`
Expected: FAIL — functions not defined

- [ ] **Step 3: Implement gh_command in bot.py**

Add to `discord-bot/bot.py`:

```python
import subprocess


def gh_command(args: list[str]) -> str:
    """Execute a gh CLI command and return stdout."""
    try:
        result = subprocess.run(
            ["gh"] + args, capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            log.warning("gh %s failed: %s", " ".join(args[:3]), result.stderr.strip())
            return result.stderr.strip()
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        log.error("gh command timed out: %s", " ".join(args[:3]))
        return "Error: command timed out"
```

- [ ] **Step 4: Implement handle_button_interaction in bot.py**

Add to `discord-bot/bot.py`:

```python
# All agent labels that might need clearing on retry
_ALL_AGENT_LABELS = [
    "agent:failed", "agent:triage", "agent:needs-info", "agent:ready",
    "agent:in-progress", "agent:pr-open", "agent:plan-review", "agent:plan-approved",
    "agent:revision",
]


async def handle_button_interaction(interaction: discord.Interaction) -> None:
    """Handle a button click on a notification message."""
    custom_id = interaction.data.get("custom_id", "")
    action, issue_number = parse_custom_id(custom_id)
    if action is None or issue_number is None:
        return

    user_id = str(interaction.user.id)
    role_ids = [str(r.id) for r in getattr(interaction.user, "roles", [])]

    if not is_authorized_check(user_id, role_ids, ALLOWED_USERS, ALLOWED_ROLE):
        await interaction.response.send_message(
            "You don't have permission to perform this action.", ephemeral=True
        )
        return

    # Modal actions: show the modal and return (modal submit handles the rest)
    if action in ("changes", "comment"):
        modal = FeedbackModal(action=action, issue_number=issue_number, repo=REPO)
        await interaction.response.send_modal(modal)
        return

    # Direct actions: defer, execute, update message
    await interaction.response.defer(ephemeral=True)

    if action == "approve":
        gh_command([
            "issue", "edit", str(issue_number), "--repo", REPO,
            "--remove-label", "agent:plan-review", "--add-label", "agent:plan-approved",
        ])
        status_text = f"Approved by {interaction.user.display_name}"
    elif action == "retry":
        gh_command([
            "issue", "edit", str(issue_number), "--repo", REPO,
            "--remove-label", ",".join(_ALL_AGENT_LABELS), "--add-label", "agent",
        ])
        status_text = f"Retried by {interaction.user.display_name}"
    else:
        await interaction.followup.send("Unknown action.", ephemeral=True)
        return

    # Update original message: add status, disable action buttons
    embed = interaction.message.embeds[0] if interaction.message.embeds else discord.Embed()
    embed.add_field(name="Action", value=status_text, inline=False)
    view = discord.ui.View(timeout=None)
    for row in interaction.message.components:
        for item in row.children:
            if hasattr(item, "url") and item.url:
                view.add_item(discord.ui.Button(label=item.label, url=item.url, style=discord.ButtonStyle.link))
    await interaction.message.edit(embed=embed, view=view)
    await interaction.followup.send(f"Done: {status_text}", ephemeral=True)
    log.info("ACTION: %s on #%d by %s (id=%s)", action, issue_number, interaction.user, interaction.user.id)
```

- [ ] **Step 5: Implement FeedbackModal in bot.py**

Add to `discord-bot/bot.py`:

```python
class FeedbackModal(discord.ui.Modal):
    """Modal dialog for collecting free-text feedback on an issue."""

    feedback = discord.ui.TextInput(
        label="Feedback",
        style=discord.TextStyle.paragraph,
        min_length=10,
        max_length=2000,
        placeholder="Describe the changes you'd like...",
    )

    def __init__(self, action: str, issue_number: int, repo: str):
        title = f"Request Changes on #{issue_number}" if action == "changes" else f"Comment on #{issue_number}"
        super().__init__(title=title[:45])  # Discord modal title limit
        self.action = action
        self.issue_number = issue_number
        self.repo = repo

    async def on_submit(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer(ephemeral=True)
        text = sanitize_input(self.feedback.value)
        gh_command(["issue", "comment", str(self.issue_number), "--repo", self.repo, "--body", text])

        # Update the original message if available
        if interaction.message and interaction.message.embeds:
            action_label = "Changes requested" if self.action == "changes" else "Comment"
            embed = interaction.message.embeds[0]
            embed.add_field(
                name="Action", value=f"{action_label} by {interaction.user.display_name}", inline=False
            )
            await interaction.message.edit(embed=embed)

        await interaction.followup.send("Feedback posted to GitHub.", ephemeral=True)
        log.info("MODAL: %s on #%d by %s (id=%s)", self.action, self.issue_number, interaction.user, interaction.user.id)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/test_interactions.py -v`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add discord-bot/bot.py discord-bot/tests/test_interactions.py
git commit -m "feat(bot): add button handlers, modal feedback, and GitHub bridge

Approve and Retry buttons execute gh CLI commands. Request Changes and
Comment buttons open a modal dialog. FeedbackModal sanitizes input and
posts via gh issue comment. Unauthorized users get ephemeral rejection."
```

---

### Task 6: Slash Commands and Bot Entrypoint

Add slash commands and the `main()` entrypoint that wires everything together.

**Files:**
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Implement slash commands in bot.py**

Add to `discord-bot/bot.py`:

```python
from discord import app_commands
from discord.ext import commands


def register_slash_commands(tree: app_commands.CommandTree) -> None:
    """Register all slash commands on the command tree."""

    @tree.command(name="approve", description="Approve an agent's plan")
    @app_commands.describe(issue="Issue number")
    async def cmd_approve(interaction: discord.Interaction, issue: int):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        gh_command([
            "issue", "edit", str(issue), "--repo", REPO,
            "--remove-label", "agent:plan-review", "--add-label", "agent:plan-approved",
        ])
        await interaction.followup.send(f"Plan for #{issue} approved.", ephemeral=True)
        log.info("SLASH: /approve #%d by %s", issue, interaction.user)

    @tree.command(name="reject", description="Reject a plan with reason")
    @app_commands.describe(issue="Issue number", reason="Reason for rejection")
    async def cmd_reject(interaction: discord.Interaction, issue: int, reason: str = ""):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        body = sanitize_input(reason) if reason else "Plan rejected via Discord."
        gh_command(["issue", "comment", str(issue), "--repo", REPO, "--body", body])
        gh_command(["issue", "edit", str(issue), "--repo", REPO, "--add-label", "agent:failed"])
        await interaction.followup.send(f"Plan for #{issue} rejected.", ephemeral=True)
        log.info("SLASH: /reject #%d by %s", issue, interaction.user)

    @tree.command(name="comment", description="Post feedback on an issue")
    @app_commands.describe(issue="Issue number", text="Your comment")
    async def cmd_comment(interaction: discord.Interaction, issue: int, text: str):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        gh_command(["issue", "comment", str(issue), "--repo", REPO, "--body", sanitize_input(text)])
        await interaction.followup.send(f"Comment posted on #{issue}.", ephemeral=True)
        log.info("SLASH: /comment #%d by %s", issue, interaction.user)

    @tree.command(name="status", description="Check agent status for an issue")
    @app_commands.describe(issue="Issue number")
    async def cmd_status(interaction: discord.Interaction, issue: int):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        labels = gh_command(["issue", "view", str(issue), "--repo", REPO, "--json", "labels", "--jq", ".labels[].name"])
        agent_labels = [l for l in labels.split("\n") if l.startswith("agent")]
        status = ", ".join(agent_labels) if agent_labels else "No agent labels"
        await interaction.followup.send(f"#{issue} status: {status}", ephemeral=True)

    @tree.command(name="retry", description="Re-trigger agent on an issue")
    @app_commands.describe(issue="Issue number")
    async def cmd_retry(interaction: discord.Interaction, issue: int):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        gh_command([
            "issue", "edit", str(issue), "--repo", REPO,
            "--remove-label", ",".join(_ALL_AGENT_LABELS), "--add-label", "agent",
        ])
        await interaction.followup.send(f"Agent re-triggered on #{issue}.", ephemeral=True)
        log.info("SLASH: /retry #%d by %s", issue, interaction.user)


def _check_slash_auth(interaction: discord.Interaction) -> bool:
    """Authorization check for slash commands."""
    user_id = str(interaction.user.id)
    role_ids = [str(r.id) for r in getattr(interaction.user, "roles", [])]
    return is_authorized_check(user_id, role_ids, ALLOWED_USERS, ALLOWED_ROLE)
```

- [ ] **Step 2: Implement the main entrypoint**

Add to the bottom of `discord-bot/bot.py`:

```python
async def start_http_server(channel) -> None:
    """Start the local HTTP server for receiving dispatch notifications."""
    app = web.Application()
    handler = create_notify_handler(channel)
    app.router.add_post("/notify", handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", BOT_PORT)
    await site.start()
    log.info("HTTP listener on 127.0.0.1:%d", BOT_PORT)


def main() -> None:
    """Bot entrypoint."""
    if not BOT_TOKEN:
        print("Error: AGENT_DISCORD_BOT_TOKEN is not set")
        raise SystemExit(1)
    if not CHANNEL_ID:
        print("Error: AGENT_DISCORD_CHANNEL_ID is not set")
        raise SystemExit(1)
    if not GUILD_ID:
        print("Error: AGENT_DISCORD_GUILD_ID is not set")
        raise SystemExit(1)
    if not REPO:
        print("Error: AGENT_DISPATCH_REPO is not set (e.g., 'owner/repo')")
        raise SystemExit(1)

    intents = discord.Intents.default()
    bot = commands.Bot(command_prefix="!", intents=intents)
    register_slash_commands(bot.tree)

    @bot.event
    async def on_ready():
        guild = discord.Object(id=GUILD_ID)
        bot.tree.copy_global_to(guild=guild)
        await bot.tree.sync(guild=guild)
        log.info("Bot ready: %s (guild %d)", bot.user, GUILD_ID)

        channel = bot.get_channel(CHANNEL_ID)
        if not channel:
            log.error("Channel %d not found — bot may not have access", CHANNEL_ID)
        await start_http_server(channel)

    @bot.event
    async def on_interaction(interaction: discord.Interaction):
        # commands.Bot handles slash commands automatically via its tree.
        # We only need to handle button clicks here.
        if interaction.type == discord.InteractionType.component:
            await handle_button_interaction(interaction)

    bot.run(BOT_TOKEN, log_handler=logging.StreamHandler(), log_level=logging.INFO)


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Verify all existing tests still pass**

Run: `cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/ -v`
Expected: All PASS

- [ ] **Step 4: Run shellcheck on modified shell files**

Run: `shellcheck ~/claude-agent-dispatch/scripts/lib/notify.sh ~/claude-agent-dispatch/scripts/lib/defaults.sh`
Expected: No warnings

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py
git commit -m "feat(bot): add slash commands and main entrypoint

Slash commands: /approve, /reject, /comment, /status, /retry.
Bot entrypoint wires Discord client, command tree, HTTP listener,
and button interaction handler together."
```

---

### Task 7: Install Script, systemd Service, and Documentation

Create the install script, systemd unit file, bot README, and update the main notifications doc.

**Files:**
- Create: `discord-bot/install.sh`
- Create: `discord-bot/agent-dispatch-bot.service`
- Create: `discord-bot/README.md`
- Modify: `docs/notifications.md`

- [ ] **Step 1: Create systemd service unit file**

Create `discord-bot/agent-dispatch-bot.service`:

```ini
[Unit]
Description=Agent Dispatch Discord Bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=WORKING_DIR
EnvironmentFile=CONFIG_PATH
ExecStart=WORKING_DIR/.venv/bin/python bot.py
Restart=on-failure
RestartSec=10
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

Note: `WORKING_DIR` and `CONFIG_PATH` are placeholders replaced by `install.sh` at install time. The script auto-detects the bot directory and prompts for the config.env path (defaulting to `$AGENT_CONFIG` or `~/agent-infra/config.env`).

- [ ] **Step 2: Create install.sh**

Create `discord-bot/install.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="agent-dispatch-bot"

echo "=== Agent Dispatch Bot Install ==="

# Determine config.env path (same logic as agent-dispatch.sh)
DEFAULT_CONFIG="${AGENT_CONFIG:-${HOME}/agent-infra/config.env}"
read -r -p "Path to config.env [${DEFAULT_CONFIG}]: " CONFIG_PATH
CONFIG_PATH="${CONFIG_PATH:-$DEFAULT_CONFIG}"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Warning: ${CONFIG_PATH} not found. Create it before starting the bot."
fi

# Create venv if it doesn't exist
if [ ! -d "${SCRIPT_DIR}/.venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "${SCRIPT_DIR}/.venv"
fi

echo "Installing dependencies..."
"${SCRIPT_DIR}/.venv/bin/pip" install -q -r "${SCRIPT_DIR}/requirements.txt"

# Install systemd service
echo "Installing systemd service..."
SERVICE_FILE="${HOME}/.config/systemd/user/${SERVICE_NAME}.service"
mkdir -p "$(dirname "$SERVICE_FILE")"

# Generate service file from template, replacing placeholders with actual paths
sed "s|WORKING_DIR|${SCRIPT_DIR}|g; s|CONFIG_PATH|${CONFIG_PATH}|g" \
    "${SCRIPT_DIR}/agent-dispatch-bot.service" > "$SERVICE_FILE"

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"

echo ""
echo "Install complete. To start the bot:"
echo "  systemctl --user start ${SERVICE_NAME}"
echo ""
echo "To check status:"
echo "  systemctl --user status ${SERVICE_NAME}"
echo "  journalctl --user -u ${SERVICE_NAME} -f"
echo ""
echo "Make sure these are set in your config.env (${CONFIG_PATH}):"
echo "  AGENT_DISCORD_BOT_TOKEN"
echo "  AGENT_DISCORD_CHANNEL_ID"
echo "  AGENT_DISCORD_GUILD_ID"
echo "  AGENT_DISCORD_ALLOWED_USERS or AGENT_DISCORD_ALLOWED_ROLE"
echo "  AGENT_DISPATCH_REPO (owner/repo format)"
echo "  AGENT_NOTIFY_BACKEND=\"bot\""
```

- [ ] **Step 3: Make install.sh executable**

```bash
chmod +x ~/claude-agent-dispatch/discord-bot/install.sh
```

- [ ] **Step 4: Create discord-bot/README.md**

Create `discord-bot/README.md`:

```markdown
# Agent Dispatch Discord Bot

Interactive Discord bot for managing agent work. Adds buttons, slash commands, and modals on top of the webhook notification layer.

## Prerequisites

- Python 3.10+
- `gh` CLI authenticated with repo access
- A Discord bot application ([create one](https://discord.com/developers/applications))

## Discord Bot Setup

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application
3. Go to Bot > Reset Token > copy the token
4. Under Privileged Gateway Intents: leave all **unchecked** (no privileged intents needed)
5. Go to OAuth2 > URL Generator:
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `View Channels`, `Send Messages`
6. Copy the generated URL and open it to invite the bot to your server
7. Get your channel ID (right-click channel > Copy Channel ID; enable Developer Mode in Discord settings if needed)
8. Get your server (guild) ID (right-click server name > Copy Server ID)

## Configuration

Add to your `config.env`:

```bash
AGENT_DISCORD_BOT_TOKEN="your-bot-token"
AGENT_DISCORD_CHANNEL_ID="123456789"
AGENT_DISCORD_GUILD_ID="987654321"
AGENT_DISCORD_ALLOWED_USERS="your-discord-user-id"  # comma-separated
# AGENT_DISCORD_ALLOWED_ROLE="role-id"              # alternative: role-based
AGENT_DISPATCH_REPO="owner/repo"                     # required: GitHub repo for gh commands
AGENT_DISCORD_BOT_PORT="8675"                        # default
AGENT_NOTIFY_BACKEND="bot"                           # switches from webhook to bot
```

## Install

```bash
./install.sh
systemctl --user start agent-dispatch-bot
```

## Verify

```bash
systemctl --user status agent-dispatch-bot
journalctl --user -u agent-dispatch-bot -f
```

## Buttons

| Button | Action |
|---|---|
| View | Link to GitHub issue/PR |
| Approve | Adds `agent:plan-approved` label, triggers implementation |
| Request Changes | Opens modal, posts comment, triggers re-triage |
| Comment | Opens modal, posts comment |
| Retry | Resets labels, adds `agent` to re-trigger |

## Slash Commands

| Command | Description |
|---|---|
| `/approve <issue>` | Approve a plan |
| `/reject <issue> [reason]` | Reject with optional reason |
| `/comment <issue> <text>` | Post feedback |
| `/status <issue>` | Check current agent labels |
| `/retry <issue>` | Re-trigger agent |

## Privacy

This bot processes Discord button clicks and slash commands to manage GitHub issues. No user data is collected or stored beyond operational logs.
```

- [ ] **Step 5: Update docs/notifications.md with Phase 2 section**

Replace the Phase 2 stub at the bottom of `docs/notifications.md` with:

```markdown
## Phase 2: Interactive Bot

The Discord bot adds interactive buttons and slash commands on top of webhook notifications. Instead of just receiving notifications, you can approve plans, request changes, post feedback, and retry failed agents directly from Discord.

### Setup

1. Create a Discord bot application and invite it to your server — see `discord-bot/README.md` for detailed steps
2. Add the bot configuration to your `config.env`:

   ```bash
   AGENT_DISCORD_BOT_TOKEN="your-bot-token"
   AGENT_DISCORD_CHANNEL_ID="123456789"
   AGENT_DISCORD_GUILD_ID="987654321"
   AGENT_DISCORD_ALLOWED_USERS="your-discord-user-id"
   AGENT_NOTIFY_BACKEND="bot"
   ```

3. Install and start the bot:

   ```bash
   cd discord-bot && ./install.sh
   systemctl --user start agent-dispatch-bot
   ```

### How It Works

When `AGENT_NOTIFY_BACKEND="bot"`, the dispatch `notify()` function POSTs to the bot's local HTTP API instead of the Discord webhook directly. The bot formats the notification with interactive buttons and sends it to your configured channel.

Button clicks and slash commands translate to `gh` CLI calls — adding labels, posting comments, and triggering workflows. The full conversation loop works:

1. Agent posts plan -> Discord notification with Approve/Request Changes buttons
2. You click Request Changes -> modal appears -> you type feedback
3. Feedback posted as GitHub comment -> triggers dispatch-reply -> agent re-triages
4. Updated plan notification -> you click Approve
5. Label added -> dispatch-implement triggers -> agent implements -> PR notification

### Fallback

If the bot is unreachable (crashed, restarting), notifications automatically fall back to the Phase 1 webhook. Agent work is never blocked by notification delivery.

### Security

Only users listed in `AGENT_DISCORD_ALLOWED_USERS` or with the role in `AGENT_DISCORD_ALLOWED_ROLE` can click action buttons and use slash commands. View/link buttons work for anyone. Unauthorized clicks get a private rejection message.
```

- [ ] **Step 6: Run shellcheck on install.sh**

Run: `shellcheck ~/claude-agent-dispatch/discord-bot/install.sh`
Expected: No warnings

- [ ] **Step 7: Run all tests (BATS + pytest)**

```bash
cd ~/claude-agent-dispatch && ./tests/bats/bin/bats tests/test_notify.bats
cd ~/claude-agent-dispatch/discord-bot && .venv/bin/pytest tests/ -v
```

Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add discord-bot/install.sh discord-bot/agent-dispatch-bot.service discord-bot/README.md docs/notifications.md
git commit -m "feat(bot): add install script, systemd service, and documentation

install.sh creates venv, installs deps, registers systemd user service.
Updated notifications.md with Phase 2 setup and usage guide."
```

---

## Verification Checklist

After all tasks, verify the complete implementation:

- [ ] `shellcheck scripts/lib/notify.sh scripts/lib/defaults.sh` — zero warnings
- [ ] `./tests/bats/bin/bats tests/test_notify.bats` — all pass
- [ ] `cd discord-bot && .venv/bin/pytest tests/ -v` — all pass
- [ ] `AGENT_NOTIFY_BACKEND=webhook` mode unchanged from Phase 1
- [ ] `AGENT_NOTIFY_BACKEND=bot` routes to localhost HTTP API
- [ ] Bot fallback to webhook when bot is down
- [ ] Bot startup requires `BOT_TOKEN`, `CHANNEL_ID`, `GUILD_ID`
- [ ] No secrets in committed files
- [ ] All new config vars documented in `config.env.example`
