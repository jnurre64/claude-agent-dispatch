# Bot Persistence Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Discord bot so it auto-starts on boot, survives gateway reconnects without port-bind errors, and has proper restart rate-limiting.

**Architecture:** Three independent fixes: (1) harden the systemd service file (remove no-op `network-online.target`, add `StartLimit*`), (2) fix `install.sh` to clean stale symlinks and recommend linger, (3) refactor `bot.py` to use discord.py's `setup_hook()` for one-time HTTP server startup instead of `on_ready` (which fires on every gateway reconnect).

**Tech Stack:** Python (discord.py 2.x, aiohttp), systemd user services, BATS/ShellCheck, pytest

**Issue:** #33

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `discord-bot/agent-dispatch-bot.service` | Modify | Remove no-op network target, add restart rate-limiting |
| `discord-bot/install.sh` | Modify | Clean stale symlinks before enable, print linger recommendation |
| `discord-bot/bot.py` | Modify | Move HTTP server startup from `on_ready` to `setup_hook()`, lazy channel resolution |
| `discord-bot/tests/test_http.py` | Modify | Update fixtures to pass mock bot instead of mock channel |

---

### Task 1: Harden the systemd service file

**Files:**
- Modify: `discord-bot/agent-dispatch-bot.service`

- [ ] **Step 1: Remove `network-online.target` lines and add `StartLimit*`**

Replace the entire `[Unit]` section. The file should become:

```ini
[Unit]
Description=Agent Dispatch Discord Bot
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
WorkingDirectory=WORKING_DIR
EnvironmentFile=CONFIG_PATH
ExecStart=WORKING_DIR/.venv/bin/python bot.py
Restart=on-failure
RestartSec=10
TimeoutStopSec=30

[Install]
WantedBy=default.target
```

`network-online.target` is a system-scope target and is silently ignored by `systemd --user` ([systemd#26305](https://github.com/systemd/systemd/issues/26305)). `Restart=on-failure` handles the boot network race. `StartLimitIntervalSec`/`StartLimitBurst` must be in `[Unit]` (silently ignored in `[Service]`).

- [ ] **Step 2: Validate with shellcheck (service file is not shell, but sanity check the template)**

Run: `grep -c 'network-online' discord-bot/agent-dispatch-bot.service`
Expected: `0` (confirms the lines are gone)

Run: `grep 'StartLimitIntervalSec' discord-bot/agent-dispatch-bot.service`
Expected: `StartLimitIntervalSec=300`

- [ ] **Step 3: Commit**

```bash
git add discord-bot/agent-dispatch-bot.service
git commit -m "fix(bot): remove no-op network-online.target, add restart rate-limiting

network-online.target is a system-scope target silently ignored by
systemd --user (systemd#26305). StartLimitIntervalSec/StartLimitBurst
prevents hot-loop on hard config errors (e.g. bad bot token).

Closes #33 (partial)"
```

---

### Task 2: Fix install.sh — clean stale symlinks and recommend linger

**Files:**
- Modify: `discord-bot/install.sh`

- [ ] **Step 1: Add `disable` before `enable` to sweep stale symlinks**

In `discord-bot/install.sh`, replace the lines:

```bash
systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
```

With:

```bash
systemctl --user daemon-reload
systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
systemctl --user enable "$SERVICE_NAME"
```

The `disable` removes any existing symlinks (including ones in the wrong target directory from a prior install). The `|| true` prevents failure if the service wasn't previously enabled.

- [ ] **Step 2: Add linger recommendation to the post-install output**

After the existing `echo` block at the end of the file (after the line about `AGENT_NOTIFY_BACKEND`), add:

```bash
echo "For the bot to start at boot (without requiring login):"
echo "  sudo loginctl enable-linger \$(whoami)"
echo ""
echo "Note: After enabling linger, 'sudo systemctl --user ...' won't work."
echo "Use 'ssh <user>@localhost' or export XDG_RUNTIME_DIR=/run/user/\$(id -u)"
```

- [ ] **Step 3: Run shellcheck**

Run: `shellcheck discord-bot/install.sh`
Expected: No warnings

- [ ] **Step 4: Commit**

```bash
git add discord-bot/install.sh
git commit -m "fix(bot): clean stale symlinks on install, recommend linger

install.sh now runs 'disable' before 'enable' to remove stale
symlinks from prior installs that may have used a different
WantedBy target (e.g. multi-user.target → default.target migration).
Also prints a linger recommendation for boot persistence.

Closes #33 (partial)"
```

---

### Task 3: Update `test_http.py` for bot-based handler (failing tests first)

**Files:**
- Modify: `discord-bot/tests/test_http.py`

- [ ] **Step 1: Rewrite fixtures to use mock bot instead of mock channel**

Replace the entire contents of `discord-bot/tests/test_http.py` with:

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
def mock_bot(mock_channel):
    bot = MagicMock()
    bot.get_channel = MagicMock(return_value=mock_channel)
    return bot


@pytest.fixture
def handler(mock_bot):
    return create_notify_handler(mock_bot)


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
    async def test_buttons_contain_repo_in_custom_id(self, handler, mock_channel, make_request):
        request = make_request(VALID_PAYLOAD)
        await handler(request)
        call_kwargs = mock_channel.send.call_args
        view = call_kwargs.kwargs["view"]
        action_buttons = [b for b in view.children if hasattr(b, "custom_id") and b.custom_id]
        assert len(action_buttons) > 0
        for button in action_buttons:
            assert "org/repo" in button.custom_id

    @pytest.mark.asyncio
    async def test_returns_503_when_channel_not_found(self, make_request):
        bot = MagicMock()
        bot.get_channel = MagicMock(return_value=None)
        handler = create_notify_handler(bot)
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

Run: `cd discord-bot && .venv/bin/python -m pytest tests/test_http.py -v`
Expected: FAIL — `create_notify_handler` currently takes a `channel`, not a `bot`. Tests pass a mock bot which doesn't match the current function signature.

- [ ] **Step 3: Commit the failing tests**

```bash
git add discord-bot/tests/test_http.py
git commit -m "test(bot): update http handler tests for bot-based channel resolution

Tests now pass a mock bot with get_channel() instead of a direct
channel reference. This supports the setup_hook refactor where the
HTTP server starts before the channel cache is populated.

Tests will fail until bot.py is updated in the next commit."
```

---

### Task 4: Refactor `bot.py` — move HTTP server to `setup_hook`, lazy channel resolution

**Files:**
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Update `create_notify_handler` to accept bot and resolve channel lazily**

In `discord-bot/bot.py`, replace the `create_notify_handler` function (lines 268-287) with:

```python
def create_notify_handler(bot):
    """Create an aiohttp handler that sends notifications via the bot's channel."""
    async def handle_notify(request: web.Request) -> web.Response:
        channel = bot.get_channel(CHANNEL_ID)
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
        view = build_buttons(event_type, issue_number, url, repo)
        await channel.send(embed=embed, view=view)
        return web.Response(text="OK")

    return handle_notify
```

- [ ] **Step 2: Update `start_http_server` to accept bot instead of channel**

Replace the `start_http_server` function (lines 290-299) with:

```python
async def start_http_server(bot) -> web.AppRunner:
    """Start the local HTTP server for receiving dispatch notifications.

    Returns the AppRunner for cleanup on shutdown.
    """
    app = web.Application()
    handler = create_notify_handler(bot)
    app.router.add_post("/notify", handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", BOT_PORT)
    await site.start()
    log.info("HTTP listener on 127.0.0.1:%d", BOT_PORT)
    return runner
```

- [ ] **Step 3: Replace `main()` with `DispatchBot` subclass using `setup_hook`**

Replace the entire `main()` function (lines 302-335) with:

```python
class DispatchBot(commands.Bot):
    """Discord bot with HTTP notification server."""

    def __init__(self) -> None:
        intents = discord.Intents.default()
        super().__init__(command_prefix="!", intents=intents)
        self._http_runner: web.AppRunner | None = None

    async def setup_hook(self) -> None:
        """Start the HTTP server once, before the gateway connects."""
        self._http_runner = await start_http_server(self)

    async def on_ready(self) -> None:
        log.info("Bot ready: %s (guild %d)", self.user, GUILD_ID)
        channel = self.get_channel(CHANNEL_ID)
        if not channel:
            log.error("Channel %d not found — bot may not have access", CHANNEL_ID)

    async def on_interaction(self, interaction: discord.Interaction) -> None:
        if interaction.type == discord.InteractionType.component:
            await handle_button_interaction(interaction)

    async def close(self) -> None:
        if self._http_runner:
            await self._http_runner.cleanup()
        await super().close()


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

    bot = DispatchBot()
    bot.run(BOT_TOKEN, log_handler=logging.StreamHandler(), log_level=logging.INFO)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run all tests**

Run: `cd discord-bot && .venv/bin/python -m pytest tests/ -v`
Expected: All 71 tests pass

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py
git commit -m "fix(bot): move HTTP server to setup_hook, fix on_ready port-bind bug

on_ready fires on every gateway reconnect (RESUME), not just once.
Starting the HTTP server there causes EADDRINUSE on the second call.

setup_hook() runs exactly once before the gateway connects (discord.py
2.0+). The HTTP server now starts there with lazy channel resolution
(bot.get_channel at request time) since the channel cache isn't
populated until after READY.

Also adds graceful cleanup of the aiohttp runner on bot shutdown.

Closes #33"
```

---

### Task 5: Run full validation suite

- [ ] **Step 1: Run pytest**

Run: `cd discord-bot && .venv/bin/python -m pytest tests/ -v`
Expected: All 71 tests pass

- [ ] **Step 2: Run shellcheck on install.sh**

Run: `shellcheck discord-bot/install.sh`
Expected: No warnings

- [ ] **Step 3: Run repo-level checks (ShellCheck + BATS)**

Run: `shellcheck scripts/*.sh scripts/lib/*.sh && ./tests/bats/bin/bats tests/`
Expected: All pass (these files were not modified but confirm no regressions)

- [ ] **Step 4: Verify service file template has no network-online.target**

Run: `grep -c 'network-online' discord-bot/agent-dispatch-bot.service`
Expected: `0`

---

### Task 6: Create PR linked to issue #33

- [ ] **Step 1: Push branch and create PR**

```bash
git push -u origin fix/bot-persistence
```

Create PR linked to #33 with summary covering all three fixes.
