# Shared `dispatch_bot` Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract shared bot logic from `discord-bot/bot.py` into a new `shared/dispatch_bot/` Python package, so a future Slack bot can reuse it. Discord bot's runtime behavior must be identical before and after.

**Architecture:** Five focused shared modules (`github`, `auth`, `sanitize`, `events`, `http_listener`) installed via editable install (`pip install -e ../shared`). Discord-specific code (embed building, UI modals, Discord interaction handling) remains in `discord-bot/bot.py`. Test suites in `shared/tests/` (new pytest) and `discord-bot/tests/` (existing, imports retargeted).

**Tech Stack:** Python 3.10+, pytest, aiohttp, discord.py, setuptools editable installs.

**Spec:** `docs/superpowers/specs/2026-04-13-shared-dispatch-bot-package-design.md`

---

## Execution notes for the engineer

- Follow tasks in order. Tasks 2-6 create the shared modules (each is a self-contained TDD cycle). Task 7 flips `discord-bot/bot.py` to import from them. Task 8 updates existing Discord tests. Task 9 verifies.
- **Do NOT modify `discord-bot/bot.py` until Task 7.** Keeping the old code in place while shared modules are built means the Discord bot stays runnable and the existing test suite stays green throughout tasks 1-6.
- Run shared tests from repo root: `pytest shared/tests/ -v`. Run Discord bot tests from `discord-bot/`: `cd discord-bot && pytest tests/ -v`.
- `shared/` must be installed editably into the same venv used for Discord bot tests: `pip install -e shared/` (see Task 1).

---

### Task 1: Bootstrap the `shared/` package skeleton

**Files:**
- Create: `shared/pyproject.toml`
- Create: `shared/dispatch_bot/__init__.py`
- Create: `shared/tests/__init__.py`
- Create: `shared/tests/conftest.py`

- [ ] **Step 1: Create package directory and files**

Create `shared/pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "dispatch_bot"
version = "0.1.0"
requires-python = ">=3.10"

[tool.setuptools.packages.find]
where = ["."]
include = ["dispatch_bot*"]
```

Create `shared/dispatch_bot/__init__.py` with a single line:

```python
"""Shared logic for claude-agent-dispatch notification bots."""
```

Create `shared/tests/__init__.py` (empty file).

Create `shared/tests/conftest.py` (empty file — placeholder; pytest will discover `dispatch_bot` via the installed package, no `sys.path` hacks needed).

- [ ] **Step 2: Install the package into the active venv**

Run from repo root (use the same venv Discord bot tests use — typically `discord-bot/.venv`):

```bash
discord-bot/.venv/bin/pip install -e shared/
```

Expected: Installation succeeds with a line like `Successfully installed dispatch_bot-0.1.0`.

On Windows use `discord-bot/.venv/Scripts/pip.exe` if running outside Git Bash.

- [ ] **Step 3: Verify the import works**

```bash
discord-bot/.venv/bin/python -c "import dispatch_bot; print(dispatch_bot.__doc__)"
```

Expected output: `Shared logic for claude-agent-dispatch notification bots.`

- [ ] **Step 4: Commit**

```bash
git add shared/
git commit -m "feat: bootstrap shared/dispatch_bot package skeleton"
```

---

### Task 2: Extract `sanitize.py`

**Files:**
- Create: `shared/dispatch_bot/sanitize.py`
- Create: `shared/tests/test_sanitize.py`

- [ ] **Step 1: Write the failing test**

Create `shared/tests/test_sanitize.py`:

```python
from dispatch_bot.sanitize import sanitize_input


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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest shared/tests/test_sanitize.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'dispatch_bot.sanitize'`.

- [ ] **Step 3: Write minimal implementation**

Create `shared/dispatch_bot/sanitize.py`:

```python
"""Input sanitization for bot-facing user text."""

import re


def sanitize_input(text: str) -> str:
    """Remove shell-dangerous characters from user input and cap length."""
    return re.sub(r"[`$\\]", "", text)[:2000]
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pytest shared/tests/test_sanitize.py -v
```

Expected: 8 passed.

- [ ] **Step 5: Commit**

```bash
git add shared/dispatch_bot/sanitize.py shared/tests/test_sanitize.py
git commit -m "feat(shared): extract sanitize_input into dispatch_bot.sanitize"
```

---

### Task 3: Extract `auth.py`

**Files:**
- Create: `shared/dispatch_bot/auth.py`
- Create: `shared/tests/test_auth.py`

- [ ] **Step 1: Write the failing test**

Create `shared/tests/test_auth.py`:

```python
from dispatch_bot.auth import is_authorized_check


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
        # Secure-by-default: empty config denies everyone
        assert not is_authorized_check(
            user_id="123", role_ids=[], allowed_users=set(), allowed_role=""
        )

    def test_user_id_or_role_either_works(self):
        assert is_authorized_check(
            user_id="123", role_ids=["999"], allowed_users={"123"}, allowed_role="888"
        )
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest shared/tests/test_auth.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'dispatch_bot.auth'`.

- [ ] **Step 3: Write implementation**

Create `shared/dispatch_bot/auth.py`:

```python
"""Authorization checks for bot actions."""


def is_authorized_check(
    user_id: str,
    role_ids: list[str],
    allowed_users: set[str],
    allowed_role: str,
) -> bool:
    """Check if a user is authorized to perform bot actions.

    Secure by default: if neither `allowed_users` nor `allowed_role` is
    configured, all users are denied.
    """
    if not allowed_users and not allowed_role:
        return False
    if user_id in allowed_users:
        return True
    if allowed_role and allowed_role in role_ids:
        return True
    return False
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pytest shared/tests/test_auth.py -v
```

Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
git add shared/dispatch_bot/auth.py shared/tests/test_auth.py
git commit -m "feat(shared): extract is_authorized_check into dispatch_bot.auth"
```

---

### Task 4: Extract `events.py`

**Files:**
- Create: `shared/dispatch_bot/events.py`
- Create: `shared/tests/test_events.py`

- [ ] **Step 1: Write the failing test**

Create `shared/tests/test_events.py`:

```python
from dispatch_bot.events import (
    EVENT_LABELS,
    EVENT_INDICATORS,
    PLAN_EVENTS,
    RETRY_EVENTS,
)


class TestEventCatalog:
    def test_plan_events_have_labels(self):
        for event in PLAN_EVENTS:
            assert event in EVENT_LABELS, f"{event} missing from EVENT_LABELS"

    def test_retry_events_have_labels(self):
        for event in RETRY_EVENTS:
            assert event in EVENT_LABELS, f"{event} missing from EVENT_LABELS"

    def test_plan_events_have_indicators(self):
        for event in PLAN_EVENTS:
            assert event in EVENT_INDICATORS, f"{event} missing from EVENT_INDICATORS"

    def test_retry_events_have_indicators(self):
        for event in RETRY_EVENTS:
            assert event in EVENT_INDICATORS, f"{event} missing from EVENT_INDICATORS"

    def test_plan_and_retry_events_disjoint(self):
        assert PLAN_EVENTS.isdisjoint(RETRY_EVENTS), \
            "an event should not be both a plan event and a retry event"

    def test_plan_posted_is_plan_event(self):
        assert "plan_posted" in PLAN_EVENTS

    def test_agent_failed_is_retry_event(self):
        assert "agent_failed" in RETRY_EVENTS

    def test_labels_are_strings(self):
        for event, label in EVENT_LABELS.items():
            assert isinstance(label, str) and label, f"{event} has empty/non-str label"

    def test_indicators_are_strings(self):
        for event, indicator in EVENT_INDICATORS.items():
            assert isinstance(indicator, str) and indicator, \
                f"{event} has empty/non-str indicator"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest shared/tests/test_events.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'dispatch_bot.events'`.

- [ ] **Step 3: Write implementation**

Create `shared/dispatch_bot/events.py`:

```python
"""Platform-agnostic event catalog for dispatch notifications.

Each event type maps to a human-readable label and a text indicator tag
(e.g. `[OK]`, `[FAIL]`) that bots can use in message titles. Event subsets
(`PLAN_EVENTS`, `RETRY_EVENTS`) declare which events get interactive
buttons for which workflows.
"""

EVENT_LABELS: dict[str, str] = {
    "plan_posted": "Plan Ready",
    "questions_asked": "Questions",
    "implement_started": "Implementation Started",
    "tests_passed": "Tests Passed",
    "tests_failed": "Tests Failed",
    "pr_created": "PR Created",
    "review_feedback": "Review Feedback",
    "review_pushed": "Review Fixes Pushed",
    "agent_failed": "Agent Failed",
}

EVENT_INDICATORS: dict[str, str] = {
    "pr_created": "[OK]",
    "tests_passed": "[OK]",
    "review_pushed": "[OK]",
    "tests_failed": "[FAIL]",
    "agent_failed": "[FAIL]",
    "plan_posted": "[INFO]",
    "questions_asked": "[INFO]",
    "review_feedback": "[ACTION]",
    "implement_started": "[INFO]",
}

PLAN_EVENTS: set[str] = {"plan_posted"}
RETRY_EVENTS: set[str] = {"agent_failed"}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pytest shared/tests/test_events.py -v
```

Expected: 9 passed.

- [ ] **Step 5: Commit**

```bash
git add shared/dispatch_bot/events.py shared/tests/test_events.py
git commit -m "feat(shared): extract event catalog into dispatch_bot.events"
```

---

### Task 5: Extract `github.py`

**Files:**
- Create: `shared/dispatch_bot/github.py`
- Create: `shared/tests/test_github.py`

- [ ] **Step 1: Write the failing test**

Create `shared/tests/test_github.py`:

```python
import subprocess
from unittest.mock import MagicMock, patch

from dispatch_bot.github import gh_command, gh_dispatch, ALL_AGENT_LABELS


class TestGhCommand:
    @patch("dispatch_bot.github.subprocess.run")
    def test_calls_gh_with_args(self, mock_run):
        mock_run.return_value = MagicMock(stdout="ok\n", returncode=0)
        gh_command(["issue", "edit", "42", "--repo", "org/repo", "--add-label", "agent"])
        mock_run.assert_called_once()
        args = mock_run.call_args[0][0]
        assert args[0] == "gh"
        assert "issue" in args
        assert "42" in args

    @patch("dispatch_bot.github.subprocess.run")
    def test_returns_success_tuple_with_stripped_stdout(self, mock_run):
        mock_run.return_value = MagicMock(stdout="  result  \n", returncode=0)
        ok, output = gh_command(["issue", "view", "1"])
        assert ok is True
        assert output == "result"

    @patch("dispatch_bot.github.subprocess.run")
    def test_handles_timeout(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(cmd="gh", timeout=30)
        ok, output = gh_command(["issue", "view", "1"])
        assert ok is False
        assert "timed out" in output.lower()

    @patch("dispatch_bot.github.subprocess.run")
    def test_handles_error(self, mock_run):
        mock_run.return_value = MagicMock(stdout="", stderr="not found", returncode=1)
        ok, output = gh_command(["issue", "view", "999"])
        assert ok is False
        assert output == "not found"


class TestGhDispatch:
    @patch("dispatch_bot.github.gh_command")
    def test_fires_repository_dispatch(self, mock_gh):
        mock_gh.return_value = (True, "")
        gh_dispatch("org/repo", "agent-implement", 42)
        mock_gh.assert_called_once()
        args = mock_gh.call_args[0][0]
        assert args[0] == "api"
        assert "repos/org/repo/dispatches" in args[1]

    @patch("dispatch_bot.github.gh_command")
    def test_passes_event_type_and_issue_number(self, mock_gh):
        mock_gh.return_value = (True, "")
        gh_dispatch("org/repo", "agent-triage", 7)
        args = mock_gh.call_args[0][0]
        assert "event_type=agent-triage" in " ".join(args)
        assert "client_payload[issue_number]=7" in " ".join(args)

    @patch("dispatch_bot.github.gh_command")
    def test_returns_gh_command_result(self, mock_gh):
        mock_gh.return_value = (False, "not found")
        ok, err = gh_dispatch("org/repo", "agent-implement", 1)
        assert ok is False
        assert err == "not found"


class TestAllAgentLabels:
    def test_contains_core_labels(self):
        assert "agent:failed" in ALL_AGENT_LABELS
        assert "agent:plan-review" in ALL_AGENT_LABELS
        assert "agent:plan-approved" in ALL_AGENT_LABELS

    def test_is_list_of_strings(self):
        assert isinstance(ALL_AGENT_LABELS, list)
        assert all(isinstance(lbl, str) for lbl in ALL_AGENT_LABELS)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest shared/tests/test_github.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'dispatch_bot.github'`.

- [ ] **Step 3: Write implementation**

Create `shared/dispatch_bot/github.py`:

```python
"""gh CLI wrappers for bot-initiated GitHub actions."""

import logging
import subprocess

log = logging.getLogger("dispatch-bot")


ALL_AGENT_LABELS: list[str] = [
    "agent:failed",
    "agent:triage",
    "agent:needs-info",
    "agent:ready",
    "agent:in-progress",
    "agent:pr-open",
    "agent:plan-review",
    "agent:plan-approved",
    "agent:revision",
]


def gh_command(args: list[str]) -> tuple[bool, str]:
    """Execute a gh CLI command and return (success, output)."""
    try:
        result = subprocess.run(
            ["gh"] + args, capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            log.warning("gh %s failed: %s", " ".join(args[:3]), result.stderr.strip())
            return False, result.stderr.strip()
        return True, result.stdout.strip()
    except subprocess.TimeoutExpired:
        log.error("gh command timed out: %s", " ".join(args[:3]))
        return False, "Error: command timed out"


def gh_dispatch(repo: str, event_type: str, issue_number: int) -> tuple[bool, str]:
    """Fire a repository_dispatch event to trigger a workflow."""
    return gh_command([
        "api", f"repos/{repo}/dispatches",
        "-f", f"event_type={event_type}",
        "-f", f"client_payload[issue_number]={issue_number}",
    ])
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pytest shared/tests/test_github.py -v
```

Expected: 9 passed.

- [ ] **Step 5: Commit**

```bash
git add shared/dispatch_bot/github.py shared/tests/test_github.py
git commit -m "feat(shared): extract gh CLI wrappers into dispatch_bot.github"
```

---

### Task 6: Extract `http_listener.py`

**Files:**
- Create: `shared/dispatch_bot/http_listener.py`
- Create: `shared/tests/test_http_listener.py`

- [ ] **Step 1: Write the failing test**

Create `shared/tests/test_http_listener.py`:

```python
import json

import pytest
from aiohttp import ClientSession, web

from dispatch_bot.http_listener import start_http_server


@pytest.mark.asyncio
async def test_serves_on_given_port_and_invokes_handler(unused_tcp_port):
    received = {}

    async def handler(request: web.Request) -> web.Response:
        received["body"] = await request.json()
        return web.Response(text="OK")

    runner = await start_http_server(handler, port=unused_tcp_port)
    try:
        async with ClientSession() as session:
            async with session.post(
                f"http://127.0.0.1:{unused_tcp_port}/notify",
                data=json.dumps({"event_type": "ping"}),
                headers={"Content-Type": "application/json"},
            ) as resp:
                assert resp.status == 200
                assert (await resp.text()) == "OK"
        assert received["body"] == {"event_type": "ping"}
    finally:
        await runner.cleanup()


@pytest.mark.asyncio
async def test_binds_to_loopback_only(unused_tcp_port):
    async def handler(request: web.Request) -> web.Response:
        return web.Response(text="OK")

    runner = await start_http_server(handler, port=unused_tcp_port)
    try:
        # The runner should have at least one site, and it should be bound to 127.0.0.1
        sites = runner.sites
        assert len(sites) == 1
        # aiohttp's TCPSite stores the host; we verify the factory defaulted correctly
        assert sites[0].name.startswith("http://127.0.0.1:")
    finally:
        await runner.cleanup()
```

Note: `unused_tcp_port` is a fixture from `pytest-asyncio`/`pytest-aiohttp`. If not available, add a local fixture that picks a free port via `socket`.

- [ ] **Step 2: Ensure pytest-asyncio is available for shared tests**

The Discord bot tests already use `@pytest.mark.asyncio`, so `pytest-asyncio` is installed in the venv. Confirm:

```bash
discord-bot/.venv/bin/pip show pytest-asyncio
```

If not installed, install it:

```bash
discord-bot/.venv/bin/pip install pytest-asyncio
```

Add a pytest config for the shared tests if asyncio mode isn't auto-detected. Create `shared/tests/conftest.py` (replacing the empty placeholder):

```python
import socket

import pytest


@pytest.fixture
def unused_tcp_port():
    """Find a free TCP port on loopback."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]
```

Also add to `shared/pyproject.toml`:

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
```

(Place this block at the end of `shared/pyproject.toml`.)

- [ ] **Step 3: Run test to verify it fails**

```bash
pytest shared/tests/test_http_listener.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'dispatch_bot.http_listener'`.

- [ ] **Step 4: Write implementation**

Create `shared/dispatch_bot/http_listener.py`:

```python
"""Local aiohttp HTTP listener factory shared across dispatch bots.

The caller supplies a request handler (which knows how to format and send
notifications to its specific platform) and a port. This module owns the
aiohttp `AppRunner` / `TCPSite` plumbing.
"""

import logging
from typing import Awaitable, Callable

from aiohttp import web

log = logging.getLogger("dispatch-bot")


async def start_http_server(
    handler: Callable[[web.Request], Awaitable[web.Response]],
    port: int,
    host: str = "127.0.0.1",
) -> web.AppRunner:
    """Start a local HTTP server listening on POST /notify.

    Returns the AppRunner so the caller can `await runner.cleanup()` on shutdown.
    """
    app = web.Application()
    app.router.add_post("/notify", handler)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, host, port)
    await site.start()
    log.info("HTTP listener on %s:%d", host, port)
    return runner
```

- [ ] **Step 5: Remove the pytest marker from the tests (asyncio_mode=auto handles it)**

If `asyncio_mode = "auto"` is set in `shared/pyproject.toml`, the `@pytest.mark.asyncio` decorators aren't required — but leaving them is harmless. Skip this step unless a test-discovery warning appears.

- [ ] **Step 6: Run test to verify it passes**

```bash
pytest shared/tests/test_http_listener.py -v
```

Expected: 2 passed.

- [ ] **Step 7: Run the full shared suite**

```bash
pytest shared/tests/ -v
```

Expected: all tests pass (8 + 6 + 9 + 9 + 2 = 34).

- [ ] **Step 8: Commit**

```bash
git add shared/dispatch_bot/http_listener.py shared/tests/test_http_listener.py shared/tests/conftest.py shared/pyproject.toml
git commit -m "feat(shared): extract aiohttp server factory into dispatch_bot.http_listener"
```

---

### Task 7: Refactor `discord-bot/bot.py` to import from `dispatch_bot`

**Files:**
- Modify: `discord-bot/bot.py` (entire file — replace extracted functions with imports)
- Modify: `discord-bot/requirements.txt`

This is the "flip" task. `bot.py` goes from defining the shared logic to importing it. Existing Discord tests may break here due to patch-target changes; Task 8 fixes them.

- [ ] **Step 1: Add editable install of shared to Discord bot requirements**

Edit `discord-bot/requirements.txt` to:

```
discord.py>=2.3,<3
aiohttp>=3.9,<4
-e ../shared
```

- [ ] **Step 2: Install the updated requirements into the Discord bot venv**

```bash
cd discord-bot && .venv/bin/pip install -r requirements.txt && cd ..
```

Expected: `dispatch_bot` already installed (from Task 1) — this step is a no-op confirmation.

- [ ] **Step 3: Rewrite `discord-bot/bot.py` to use shared modules**

Replace the entire content of `discord-bot/bot.py` with:

```python
"""Discord bot for claude-agent-dispatch interactive notifications."""

import logging
import os

import discord
from discord.ext import commands
from aiohttp import web

from dispatch_bot.events import (
    EVENT_INDICATORS,
    EVENT_LABELS,
    PLAN_EVENTS,
    RETRY_EVENTS,
)
from dispatch_bot.github import ALL_AGENT_LABELS, gh_command, gh_dispatch
from dispatch_bot.auth import is_authorized_check
from dispatch_bot.sanitize import sanitize_input
from dispatch_bot.http_listener import start_http_server

log = logging.getLogger("dispatch-bot")

# --- Configuration (from environment) ---
BOT_TOKEN = os.environ.get("AGENT_DISCORD_BOT_TOKEN", "")
CHANNEL_ID = int(os.environ.get("AGENT_DISCORD_CHANNEL_ID", "0"))
GUILD_ID = int(os.environ.get("AGENT_DISCORD_GUILD_ID", "0"))
ALLOWED_USERS = set(os.environ.get("AGENT_DISCORD_ALLOWED_USERS", "").split(",")) - {""}
ALLOWED_ROLE = os.environ.get("AGENT_DISCORD_ALLOWED_ROLE", "")
BOT_PORT = int(os.environ.get("AGENT_DISCORD_BOT_PORT", "8675"))


def parse_custom_id(custom_id: str) -> tuple[str | None, str | None, int | None]:
    """Parse 'action:owner/repo:issue_number' from a button custom_id."""
    parts = custom_id.split(":")
    if len(parts) < 3:
        return None, None, None
    action = parts[0]
    num_str = parts[-1]
    repo = ":".join(parts[1:-1])
    try:
        return action, repo, int(num_str)
    except ValueError:
        return None, None, None


# --- Discord-specific event colors (hex ints for discord.Embed) ---
EVENT_COLORS = {
    "pr_created": 0x57F287, "tests_passed": 0x57F287, "review_pushed": 0x57F287,
    "tests_failed": 0xED4245, "agent_failed": 0xED4245,
    "plan_posted": 0x3498DB, "questions_asked": 0x3498DB,
    "review_feedback": 0xFFFF00,
}


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


def build_buttons(event_type: str, issue_number: int, url: str, repo: str) -> discord.ui.View:
    """Build interactive buttons for a notification message."""
    view = discord.ui.View(timeout=None)
    view.add_item(discord.ui.Button(label="View", url=url, style=discord.ButtonStyle.link))

    if event_type in PLAN_EVENTS:
        view.add_item(discord.ui.Button(
            label="Approve", custom_id=f"approve:{repo}:{issue_number}", style=discord.ButtonStyle.success
        ))
        view.add_item(discord.ui.Button(
            label="Request Changes", custom_id=f"changes:{repo}:{issue_number}", style=discord.ButtonStyle.danger
        ))
        view.add_item(discord.ui.Button(
            label="Comment", custom_id=f"comment:{repo}:{issue_number}", style=discord.ButtonStyle.secondary
        ))
    elif event_type in RETRY_EVENTS:
        view.add_item(discord.ui.Button(
            label="Retry", custom_id=f"retry:{repo}:{issue_number}", style=discord.ButtonStyle.primary
        ))

    return view


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
        super().__init__(title=title[:45])
        self.action = action
        self.issue_number = issue_number
        self.repo = repo

    async def on_submit(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer(ephemeral=True)
        text = sanitize_input(self.feedback.value)
        ok, err = gh_command(["issue", "comment", str(self.issue_number), "--repo", self.repo, "--body", text])
        if not ok:
            await interaction.followup.send(
                f"Failed to comment on #{self.issue_number}: {err}", ephemeral=True
            )
            return

        if interaction.message and interaction.message.embeds:
            action_label = "Changes requested" if self.action == "changes" else "Comment"
            embed = interaction.message.embeds[0]
            embed.add_field(
                name="Action", value=f"{action_label} by {interaction.user.display_name}", inline=False
            )
            await interaction.message.edit(embed=embed)

        gh_dispatch(self.repo, "agent-reply", self.issue_number)
        await interaction.followup.send("Feedback posted to GitHub.", ephemeral=True)
        log.info("MODAL: %s on %s#%d by %s (id=%s)", self.action, self.repo, self.issue_number, interaction.user, interaction.user.id)


async def handle_button_interaction(interaction: discord.Interaction) -> None:
    """Handle a button click on a notification message."""
    custom_id = interaction.data.get("custom_id", "")
    action, repo, issue_number = parse_custom_id(custom_id)
    if action is None or repo is None or issue_number is None:
        return

    user_id = str(interaction.user.id)
    role_ids = [str(r.id) for r in getattr(interaction.user, "roles", [])]

    if not is_authorized_check(user_id, role_ids, ALLOWED_USERS, ALLOWED_ROLE):
        await interaction.response.send_message(
            "You don't have permission to perform this action.", ephemeral=True
        )
        return

    if action in ("changes", "comment"):
        modal = FeedbackModal(action=action, issue_number=issue_number, repo=repo)
        await interaction.response.send_modal(modal)
        return

    await interaction.response.defer(ephemeral=True)

    if action == "approve":
        ok, err = gh_command([
            "issue", "edit", str(issue_number), "--repo", repo,
            "--remove-label", "agent:plan-review", "--add-label", "agent:plan-approved",
        ])
        status_text = f"Approved by {interaction.user.display_name}"
    elif action == "retry":
        ok, err = gh_command([
            "issue", "edit", str(issue_number), "--repo", repo,
            "--remove-label", ",".join(ALL_AGENT_LABELS), "--add-label", "agent",
        ])
        status_text = f"Retried by {interaction.user.display_name}"
    else:
        await interaction.followup.send("Unknown action.", ephemeral=True)
        return

    if not ok:
        await interaction.followup.send(
            f"Failed to update GitHub issue #{issue_number}: {err}", ephemeral=True
        )
        return

    dispatch_events = {"approve": "agent-implement", "retry": "agent-triage"}
    dispatch_ok, dispatch_err = gh_dispatch(repo, dispatch_events[action], issue_number)

    embed = interaction.message.embeds[0] if interaction.message.embeds else discord.Embed()
    embed.add_field(name="Action", value=status_text, inline=False)
    view = discord.ui.View(timeout=None)
    for row in interaction.message.components:
        for item in row.children:
            if hasattr(item, "url") and item.url:
                view.add_item(discord.ui.Button(label=item.label, url=item.url, style=discord.ButtonStyle.link))
    await interaction.message.edit(embed=embed, view=view)

    if not dispatch_ok:
        await interaction.followup.send(
            f"Done: {status_text} (warning: workflow trigger failed — {dispatch_err})",
            ephemeral=True,
        )
    else:
        await interaction.followup.send(f"Done: {status_text}", ephemeral=True)
    log.info("ACTION: %s on %s#%d by %s (id=%s)", action, repo, issue_number, interaction.user, interaction.user.id)


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


class DispatchBot(commands.Bot):
    """Discord bot with HTTP notification server."""

    def __init__(self) -> None:
        intents = discord.Intents.default()
        super().__init__(command_prefix="!", intents=intents)
        self._http_runner: web.AppRunner | None = None

    async def setup_hook(self) -> None:
        """Start the HTTP server once, before the gateway connects."""
        handler = create_notify_handler(self)
        self._http_runner = await start_http_server(handler, port=BOT_PORT)

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

Key differences from the pre-refactor version:

- `re` and `subprocess` imports removed (no longer used directly)
- `sanitize_input`, `is_authorized_check`, `gh_command`, `gh_dispatch`, `_ALL_AGENT_LABELS` (now `ALL_AGENT_LABELS`) removed from bot.py — imported instead
- `EVENT_LABELS`, `EVENT_INDICATORS`, `_PLAN_EVENTS`/`_RETRY_EVENTS` (now `PLAN_EVENTS`/`RETRY_EVENTS`) imported from `dispatch_bot.events`
- `start_http_server` removed from bot.py — imported. Now called as `start_http_server(handler, port=BOT_PORT)` from `setup_hook`.
- `build_buttons` references `PLAN_EVENTS` / `RETRY_EVENTS` instead of the underscore-prefixed versions
- `handle_button_interaction` references `ALL_AGENT_LABELS` instead of `_ALL_AGENT_LABELS`
- `EVENT_COLORS` stays (Discord-specific)
- `parse_custom_id`, `build_embed`, `build_buttons`, `FeedbackModal`, `handle_button_interaction`, `create_notify_handler`, `DispatchBot` all stay

- [ ] **Step 4: Verify bot.py imports resolve**

```bash
cd discord-bot && .venv/bin/python -c "import bot; print('OK')" && cd ..
```

Expected: `OK`.

- [ ] **Step 5: Commit (tests will break in Task 8)**

```bash
git add discord-bot/bot.py discord-bot/requirements.txt
git commit -m "refactor(discord-bot): import shared logic from dispatch_bot package"
```

---

### Task 8: Update `discord-bot/tests/` imports and patch targets

**Files:**
- Modify: `discord-bot/tests/test_utils.py`
- Modify: `discord-bot/tests/test_embeds.py`
- Modify: `discord-bot/tests/test_interactions.py`
- Modify: `discord-bot/tests/test_http.py`

Strategy: only change `from bot import ...` lines and `@patch("bot.X")` targets. All assertions stay the same. This keeps the behavioral-parity guarantee visible: the test diff should show only imports and patch paths.

- [ ] **Step 1: Update `discord-bot/tests/test_utils.py`**

Replace the first line:

```python
from bot import sanitize_input, parse_custom_id, is_authorized_check
```

with:

```python
from bot import parse_custom_id
from dispatch_bot.auth import is_authorized_check
from dispatch_bot.sanitize import sanitize_input
```

No other changes in this file.

- [ ] **Step 2: Update `discord-bot/tests/test_embeds.py`**

Replace:

```python
from bot import build_embed, build_buttons, EVENT_COLORS, EVENT_LABELS, EVENT_INDICATORS
```

with:

```python
from bot import build_embed, build_buttons, EVENT_COLORS
from dispatch_bot.events import EVENT_LABELS, EVENT_INDICATORS  # noqa: F401 (imported for test surface)
```

Note: `EVENT_LABELS` and `EVENT_INDICATORS` aren't actually referenced in `test_embeds.py` (check the current file — they're imported but unused). If they are unused, remove the import entirely:

```python
from bot import build_embed, build_buttons, EVENT_COLORS
```

Verify by running `grep -E "EVENT_LABELS|EVENT_INDICATORS" discord-bot/tests/test_embeds.py` after the edit — it should only find the import line (if any).

- [ ] **Step 3: Update `discord-bot/tests/test_interactions.py`**

Update the import block at the top:

```python
import subprocess
from unittest.mock import AsyncMock, MagicMock, patch, PropertyMock

import discord
import pytest

from bot import (
    handle_button_interaction,
    parse_custom_id,
    FeedbackModal,
    ALLOWED_USERS,
    ALLOWED_ROLE,
)
from dispatch_bot.github import gh_command, gh_dispatch
```

Then update patch targets. In `TestGhCommand`, change `@patch("bot.subprocess.run")` (4 occurrences) to `@patch("dispatch_bot.github.subprocess.run")`.

In `TestGhDispatch`, change `@patch("bot.gh_command")` (3 occurrences) to `@patch("dispatch_bot.github.gh_command")`. These patches target the reference inside `dispatch_bot.github` because `gh_dispatch` is called directly in these tests and it looks up `gh_command` from its own module.

In `TestHandleButtonInteraction`, `@patch("bot.gh_command")` and `@patch("bot.gh_dispatch")` **stay as-is** — `handle_button_interaction` lives in `bot.py` and references these names through bot's module namespace (because they were imported into `bot.py` via `from dispatch_bot.github import gh_command, gh_dispatch`).

In `TestFeedbackModal`, the `@patch("bot.gh_command")` and `@patch("bot.gh_dispatch")` on `test_on_submit_fires_reply_dispatch` similarly **stay as-is** — `FeedbackModal.on_submit` lives in `bot.py`.

Summary of patch-target changes in this file:
- `bot.subprocess.run` → `dispatch_bot.github.subprocess.run` (4 times, in `TestGhCommand`)
- `bot.gh_command` in `TestGhDispatch` → `dispatch_bot.github.gh_command` (3 times)
- All other patches unchanged

- [ ] **Step 4: Update `discord-bot/tests/test_http.py`**

No changes needed — `create_notify_handler` still lives in `bot`. Verify:

```bash
cat discord-bot/tests/test_http.py | head -10
```

The import line `from bot import create_notify_handler` stays.

- [ ] **Step 5: Run the full Discord bot test suite**

```bash
cd discord-bot && .venv/bin/pytest tests/ -v && cd ..
```

Expected: all pre-existing tests pass (same count as before the refactor).

If any test fails, inspect the failure. Most likely causes:
- A patch target still points at a name that no longer lives in `bot.py` → retarget to `dispatch_bot.<module>.<name>`
- An import from `bot` that was removed in Task 7 → retarget to the correct `dispatch_bot` submodule

- [ ] **Step 6: Run the full shared test suite again to confirm nothing regressed**

```bash
pytest shared/tests/ -v
```

Expected: all shared tests still pass.

- [ ] **Step 7: Commit**

```bash
git add discord-bot/tests/
git commit -m "test(discord-bot): retarget imports and patch paths to dispatch_bot"
```

---

### Task 9: Verify install, static checks, and BATS

**Files:**
- No modifications expected. This task is a verification pass.

- [ ] **Step 1: Fresh-venv install smoke test**

Remove the existing venv and re-run `install.sh` to confirm the editable install path works from a clean slate. Back up first in case something breaks:

```bash
mv discord-bot/.venv discord-bot/.venv.bak
bash discord-bot/install.sh <<< ""
```

(The heredoc `<<< ""` accepts the default `config.env` prompt.)

Expected: venv is recreated, `pip install -r requirements.txt` runs, `dispatch_bot` is installed via the `-e ../shared` line, no errors.

Verify `dispatch_bot` is installed:

```bash
discord-bot/.venv/bin/pip show dispatch_bot
```

Expected: shows `Name: dispatch_bot`, `Version: 0.1.0`, `Location: .../shared`.

- [ ] **Step 2: Verify the bot can import cleanly in the fresh venv**

```bash
cd discord-bot && .venv/bin/python -c "import bot; print('OK')" && cd ..
```

Expected: `OK`.

- [ ] **Step 3: Run all tests in the fresh venv**

```bash
cd discord-bot && .venv/bin/pytest tests/ -v && cd ..
discord-bot/.venv/bin/pytest shared/tests/ -v
```

Expected: both suites pass.

- [ ] **Step 4: Restore the backup venv (or delete it if Step 1-3 succeeded)**

```bash
rm -rf discord-bot/.venv.bak
```

- [ ] **Step 5: Run shellcheck**

```bash
shellcheck scripts/*.sh scripts/lib/*.sh
```

Expected: zero warnings.

- [ ] **Step 6: Run BATS suite**

```bash
./tests/bats/bin/bats tests/
```

Expected: all tests pass.

- [ ] **Step 7: Manual smoke test (optional but recommended before merging)**

Start the bot against a real Discord channel and send a test notification:

```bash
# Terminal 1 (with AGENT_DISCORD_* env vars loaded from config.env)
cd discord-bot && .venv/bin/python bot.py

# Terminal 2
curl -X POST http://127.0.0.1:8675/notify \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "plan_posted",
    "title": "Smoke test",
    "url": "https://github.com/example/repo/issues/1",
    "description": "Testing post-refactor behavior",
    "issue_number": 1,
    "repo": "example/repo"
  }'
```

Expected: message appears in the configured Discord channel with Approve / Request Changes / Comment / View buttons. Clicking Approve (as an authorized user) should add `agent:plan-approved` to issue #1.

Stop the bot with Ctrl-C.

- [ ] **Step 8: Final commit (if any verification tweaks were needed; otherwise skip)**

If no code changed during verification, no commit. Otherwise:

```bash
git add <changed files>
git commit -m "fix: <what was fixed during verification>"
```

---

## Rollback

If something goes wrong and the refactor must be undone:

```bash
git log --oneline | head -15     # find the commit before Task 1
git reset --hard <commit-before-task-1>
rm -rf shared/
cd discord-bot && .venv/bin/pip uninstall -y dispatch_bot && cd ..
```

The pre-refactor `bot.py` will be restored and the venv will no longer reference `dispatch_bot`.

---

## Out of scope (from spec)

- Slack code
- Changes to `scripts/lib/notify.sh`
- New config vars
- Severity abstraction in `events.py`
- Auth function renames
- Adding Python tests to CI
