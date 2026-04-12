# Discord Bot Repository Dispatch Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the Discord bot to trigger GitHub Actions workflows via `repository_dispatch`, bypassing the bot actor guard that prevents the bot's own label/comment events from triggering workflows.

**Architecture:** Add an optional `issue_number` input to the three issue-based reusable workflows (`dispatch-triage.yml`, `dispatch-implement.yml`, `dispatch-reply.yml`) so they can receive the issue number from a `repository_dispatch` payload instead of `github.event`. Create one new caller template and one new standalone template that listen for `repository_dispatch` and route to the correct reusable workflow. Add a `gh_dispatch` helper to the Discord bot that fires the dispatch event after each GitHub action.

**Tech Stack:** GitHub Actions (YAML workflows), Python (discord.py bot), BATS (shell tests), pytest (bot tests)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `.github/workflows/dispatch-triage.yml` | Modify | Add optional `issue_number` input with fallback |
| `.github/workflows/dispatch-implement.yml` | Modify | Add optional `issue_number` input with fallback |
| `.github/workflows/dispatch-reply.yml` | Modify | Add optional `issue_number` input with fallback |
| `.claude/skills/setup/templates/caller-dispatch.yml` | Create | Reference-mode caller for `repository_dispatch` events |
| `.claude/skills/setup/templates/standalone/agent-dispatch.yml` | Create | Standalone-mode handler for `repository_dispatch` events |
| `.claude/skills/setup/SKILL.md` | Modify | Document the new optional dispatch template in Step 6 |
| `discord-bot/bot.py` | Modify | Add `gh_dispatch` helper, call it from all action handlers |
| `discord-bot/tests/test_interactions.py` | Modify | Test dispatch is fired after each action |

---

### Task 1: Add `issue_number` input to `dispatch-triage.yml`

**Files:**
- Modify: `.github/workflows/dispatch-triage.yml`

- [ ] **Step 1: Add the optional input to workflow_call**

In `.github/workflows/dispatch-triage.yml`, add `issue_number` to the `inputs` block after `bot_user`:

```yaml
      issue_number:
        description: 'Issue number override (for repository_dispatch triggers)'
        required: false
        type: string
        default: ''
```

- [ ] **Step 2: Update the concurrency group to use the input with fallback**

Change the concurrency block from:

```yaml
concurrency:
  group: claude-agent-${{ github.event.issue.number }}
  cancel-in-progress: false
```

To:

```yaml
concurrency:
  group: claude-agent-${{ inputs.issue_number || github.event.issue.number }}
  cancel-in-progress: false
```

- [ ] **Step 3: Update the script invocation to use the input with fallback**

Change the run command from:

```yaml
        run: |
          ${{ inputs.dispatch_script }} \
            new_issue \
            "${{ github.repository }}" \
            "${{ github.event.issue.number }}"
```

To:

```yaml
        run: |
          ${{ inputs.dispatch_script }} \
            new_issue \
            "${{ github.repository }}" \
            "${{ inputs.issue_number || github.event.issue.number }}"
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/dispatch-triage.yml
git commit -m "feat(workflows): add optional issue_number input to dispatch-triage"
```

---

### Task 2: Add `issue_number` input to `dispatch-implement.yml`

**Files:**
- Modify: `.github/workflows/dispatch-implement.yml`

- [ ] **Step 1: Add the optional input to workflow_call**

In `.github/workflows/dispatch-implement.yml`, add `issue_number` to the `inputs` block after `bot_user`:

```yaml
      issue_number:
        description: 'Issue number override (for repository_dispatch triggers)'
        required: false
        type: string
        default: ''
```

- [ ] **Step 2: Update the concurrency group to use the input with fallback**

Change the concurrency block from:

```yaml
concurrency:
  group: claude-agent-${{ github.event.issue.number }}
  cancel-in-progress: false
```

To:

```yaml
concurrency:
  group: claude-agent-${{ inputs.issue_number || github.event.issue.number }}
  cancel-in-progress: false
```

- [ ] **Step 3: Update the script invocation to use the input with fallback**

Change the run command from:

```yaml
        run: |
          ${{ inputs.dispatch_script }} \
            implement \
            "${{ github.repository }}" \
            "${{ github.event.issue.number }}"
```

To:

```yaml
        run: |
          ${{ inputs.dispatch_script }} \
            implement \
            "${{ github.repository }}" \
            "${{ inputs.issue_number || github.event.issue.number }}"
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/dispatch-implement.yml
git commit -m "feat(workflows): add optional issue_number input to dispatch-implement"
```

---

### Task 3: Add `issue_number` input to `dispatch-reply.yml`

**Files:**
- Modify: `.github/workflows/dispatch-reply.yml`

- [ ] **Step 1: Add the optional input to workflow_call**

In `.github/workflows/dispatch-reply.yml`, add `issue_number` to the `inputs` block after `bot_user`:

```yaml
      issue_number:
        description: 'Issue number override (for repository_dispatch triggers)'
        required: false
        type: string
        default: ''
```

- [ ] **Step 2: Update the concurrency group to use the input with fallback**

Change the concurrency block from:

```yaml
concurrency:
  group: claude-agent-${{ github.event.issue.number }}
  cancel-in-progress: false
```

To:

```yaml
concurrency:
  group: claude-agent-${{ inputs.issue_number || github.event.issue.number }}
  cancel-in-progress: false
```

- [ ] **Step 3: Update the script invocation to use the input with fallback**

Change the run command from:

```yaml
        run: |
          ${{ inputs.dispatch_script }} \
            issue_reply \
            "${{ github.repository }}" \
            "${{ github.event.issue.number }}"
```

To:

```yaml
        run: |
          ${{ inputs.dispatch_script }} \
            issue_reply \
            "${{ github.repository }}" \
            "${{ inputs.issue_number || github.event.issue.number }}"
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/dispatch-reply.yml
git commit -m "feat(workflows): add optional issue_number input to dispatch-reply"
```

---

### Task 4: Create the reference-mode caller template

**Files:**
- Create: `.claude/skills/setup/templates/caller-dispatch.yml`

- [ ] **Step 1: Create the caller template**

Create `.claude/skills/setup/templates/caller-dispatch.yml`:

```yaml
name: "Claude Agent: Discord Dispatch"

on:
  repository_dispatch:
    types: [agent-triage, agent-implement, agent-reply]

jobs:
  triage:
    if: github.event.action == 'agent-triage'
    uses: jnurre64/claude-agent-dispatch/.github/workflows/dispatch-triage.yml@v1
    with:
      bot_user: "{{BOT_USER}}"
      issue_number: "${{ github.event.client_payload.issue_number }}"
    secrets:
      agent_pat: ${{ secrets.AGENT_PAT }}

  implement:
    if: github.event.action == 'agent-implement'
    uses: jnurre64/claude-agent-dispatch/.github/workflows/dispatch-implement.yml@v1
    with:
      bot_user: "{{BOT_USER}}"
      issue_number: "${{ github.event.client_payload.issue_number }}"
    secrets:
      agent_pat: ${{ secrets.AGENT_PAT }}

  reply:
    if: github.event.action == 'agent-reply'
    uses: jnurre64/claude-agent-dispatch/.github/workflows/dispatch-reply.yml@v1
    with:
      bot_user: "{{BOT_USER}}"
      issue_number: "${{ github.event.client_payload.issue_number }}"
    secrets:
      agent_pat: ${{ secrets.AGENT_PAT }}
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/setup/templates/caller-dispatch.yml
git commit -m "feat(templates): add reference-mode caller for repository_dispatch"
```

---

### Task 5: Create the standalone-mode dispatch template

**Files:**
- Create: `.claude/skills/setup/templates/standalone/agent-dispatch.yml`

- [ ] **Step 1: Create the standalone template**

Create `.claude/skills/setup/templates/standalone/agent-dispatch.yml`:

```yaml
name: "Claude Agent: Discord Dispatch"

on:
  repository_dispatch:
    types: [agent-triage, agent-implement, agent-reply]

concurrency:
  group: claude-agent-${{ github.event.client_payload.issue_number }}
  cancel-in-progress: false

jobs:
  triage:
    if: github.event.action == 'agent-triage'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (triage)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            new_issue \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"

  implement:
    if: github.event.action == 'agent-implement'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (implement)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            implement \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"

  reply:
    if: github.event.action == 'agent-reply'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (reply)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            issue_reply \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/setup/templates/standalone/agent-dispatch.yml
git commit -m "feat(templates): add standalone-mode handler for repository_dispatch"
```

---

### Task 6: Update the setup skill to document the dispatch template

**Files:**
- Modify: `.claude/skills/setup/SKILL.md`

- [ ] **Step 1: Read the current SKILL.md Step 6 section**

Read `.claude/skills/setup/SKILL.md` to see the full Step 6 content.

- [ ] **Step 2: Add the dispatch template to Step 6**

After the existing template lists in Step 6 (after the "For each template:" instructions), add:

```markdown
### Discord bot dispatch (optional)

If the user has set up the Discord bot (see `docs/notifications.md`), also deploy the dispatch template:

- **Reference mode:** `caller-dispatch.yml`
- **Standalone mode:** `agent-dispatch.yml` (from `templates/standalone/`)

This template enables the Discord bot's Approve, Retry, Comment, and Request Changes actions to trigger agent workflows. It is only needed if the Discord bot is in use.
```

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/setup/SKILL.md
git commit -m "docs(setup): document optional discord dispatch template in Step 6"
```

---

### Task 7: Add `gh_dispatch` helper to the Discord bot

**Files:**
- Modify: `discord-bot/bot.py`
- Test: `discord-bot/tests/test_interactions.py`

- [ ] **Step 1: Write the failing test for `gh_dispatch`**

In `discord-bot/tests/test_interactions.py`, add the import and test class after the existing `TestGhCommand` class:

```python
from bot import (
    gh_command,
    gh_dispatch,
    handle_button_interaction,
    FeedbackModal,
    ALLOWED_USERS,
    ALLOWED_ROLE,
)


class TestGhDispatch:
    @patch("bot.gh_command")
    def test_fires_repository_dispatch(self, mock_gh):
        mock_gh.return_value = (True, "")
        gh_dispatch("org/repo", "agent-implement", 42)
        mock_gh.assert_called_once()
        args = mock_gh.call_args[0][0]
        assert args[0] == "api"
        assert "repos/org/repo/dispatches" in args[1]

    @patch("bot.gh_command")
    def test_passes_event_type_and_issue_number(self, mock_gh):
        mock_gh.return_value = (True, "")
        gh_dispatch("org/repo", "agent-triage", 7)
        args = mock_gh.call_args[0][0]
        assert "event_type=agent-triage" in " ".join(args)
        assert "issue_number=7" in " ".join(args)

    @patch("bot.gh_command")
    def test_returns_gh_command_result(self, mock_gh):
        mock_gh.return_value = (False, "not found")
        ok, err = gh_dispatch("org/repo", "agent-implement", 1)
        assert ok is False
        assert err == "not found"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/test_interactions.py::TestGhDispatch -v
```

Expected: FAIL — `ImportError: cannot import name 'gh_dispatch'`

- [ ] **Step 3: Implement `gh_dispatch`**

In `discord-bot/bot.py`, add the following function directly after the `gh_command` function (after line 136):

```python
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
cd discord-bot && .venv/bin/python -m pytest tests/test_interactions.py::TestGhDispatch -v
```

Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py discord-bot/tests/test_interactions.py
git commit -m "feat(bot): add gh_dispatch helper for repository_dispatch events"
```

---

### Task 8: Wire `gh_dispatch` into button handlers (approve + retry)

**Files:**
- Modify: `discord-bot/bot.py`
- Modify: `discord-bot/tests/test_interactions.py`

- [ ] **Step 1: Write the failing test for approve dispatching**

In `discord-bot/tests/test_interactions.py`, add to `TestHandleButtonInteraction`:

```python
    @patch("bot.gh_dispatch")
    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_approve_fires_dispatch(self, mock_gh, mock_dispatch):
        mock_gh.return_value = (True, "")
        mock_dispatch.return_value = (True, "")
        interaction = _mock_interaction("approve:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        mock_dispatch.assert_called_once_with("org/repo", "agent-implement", 42)

    @patch("bot.gh_dispatch")
    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_retry_fires_dispatch(self, mock_gh, mock_dispatch):
        mock_gh.return_value = (True, "")
        mock_dispatch.return_value = (True, "")
        interaction = _mock_interaction("retry:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        mock_dispatch.assert_called_once_with("org/repo", "agent-triage", 42)

    @patch("bot.gh_dispatch")
    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_dispatch_failure_still_shows_success(self, mock_gh, mock_dispatch):
        mock_gh.return_value = (True, "")
        mock_dispatch.return_value = (False, "dispatch failed")
        interaction = _mock_interaction("approve:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        # Label succeeded, so Discord UI should still update
        interaction.message.edit.assert_called_once()
        # But warn the user about the dispatch failure
        followup_msg = interaction.followup.send.call_args[0][0]
        assert "dispatch" in followup_msg.lower() or "trigger" in followup_msg.lower()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/test_interactions.py::TestHandleButtonInteraction::test_approve_fires_dispatch tests/test_interactions.py::TestHandleButtonInteraction::test_retry_fires_dispatch tests/test_interactions.py::TestHandleButtonInteraction::test_dispatch_failure_still_shows_success -v
```

Expected: FAIL

- [ ] **Step 3: Wire `gh_dispatch` into `handle_button_interaction`**

In `discord-bot/bot.py`, in `handle_button_interaction`, after the `if not ok: return` guard and before the embed update block, add the dispatch calls. The updated section (starting from the `if not ok` guard) should read:

```python
    if not ok:
        await interaction.followup.send(
            f"Failed to update GitHub issue #{issue_number}: {err}", ephemeral=True
        )
        return

    # Map button actions to dispatch event types
    dispatch_events = {"approve": "agent-implement", "retry": "agent-triage"}
    dispatch_ok, dispatch_err = gh_dispatch(REPO, dispatch_events[action], issue_number)

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
    log.info("ACTION: %s on #%d by %s (id=%s)", action, issue_number, interaction.user, interaction.user.id)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/test_interactions.py::TestHandleButtonInteraction -v
```

Expected: all pass

Note: The existing `test_approve_adds_label` and `test_approve_sends_ephemeral_confirmation` tests mock `gh_command` but not `gh_dispatch`. Since `gh_dispatch` calls `gh_command` internally, the existing mock will cover it. However, if they fail because `gh_command` is now called twice (once for label, once inside `gh_dispatch`), update those tests to also patch `gh_dispatch`:

```python
    @patch("bot.gh_dispatch")
    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_approve_adds_label(self, mock_gh, mock_dispatch):
        mock_gh.return_value = (True, "")
        mock_dispatch.return_value = (True, "")
        interaction = _mock_interaction("approve:42", user_id="123")
        with patch("bot.ALLOWED_USERS", {"123"}), patch("bot.REPO", "org/repo"):
            await handle_button_interaction(interaction)
        calls = [str(c) for c in mock_gh.call_args_list]
        combined = " ".join(calls)
        assert "plan-approved" in combined
```

Apply the same `@patch("bot.gh_dispatch")` + `mock_dispatch.return_value = (True, "")` pattern to `test_approve_sends_ephemeral_confirmation`, `test_approve_failure_reports_error`, and `test_retry_resets_labels`.

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py discord-bot/tests/test_interactions.py
git commit -m "feat(bot): fire repository_dispatch from approve and retry buttons"
```

---

### Task 9: Wire `gh_dispatch` into slash commands (approve + retry)

**Files:**
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Update `/approve` slash command**

In the `cmd_approve` function inside `register_slash_commands`, add the dispatch call after the successful label update and before the success message:

```python
    async def cmd_approve(interaction: discord.Interaction, issue: int):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        ok, err = gh_command([
            "issue", "edit", str(issue), "--repo", REPO,
            "--remove-label", "agent:plan-review", "--add-label", "agent:plan-approved",
        ])
        if not ok:
            await interaction.followup.send(f"Failed to update #{issue}: {err}", ephemeral=True)
            return
        gh_dispatch(REPO, "agent-implement", issue)
        await interaction.followup.send(f"Plan for #{issue} approved.", ephemeral=True)
        log.info("SLASH: /approve #%d by %s", issue, interaction.user)
```

- [ ] **Step 2: Update `/retry` slash command**

In the `cmd_retry` function, add the dispatch call after the successful label update:

```python
    async def cmd_retry(interaction: discord.Interaction, issue: int):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        ok, err = gh_command([
            "issue", "edit", str(issue), "--repo", REPO,
            "--remove-label", ",".join(_ALL_AGENT_LABELS), "--add-label", "agent",
        ])
        if not ok:
            await interaction.followup.send(f"Failed to update #{issue}: {err}", ephemeral=True)
            return
        gh_dispatch(REPO, "agent-triage", issue)
        await interaction.followup.send(f"Agent re-triggered on #{issue}.", ephemeral=True)
        log.info("SLASH: /retry #%d by %s", issue, interaction.user)
```

- [ ] **Step 3: Run full bot test suite**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/ -v
```

Expected: all pass

- [ ] **Step 4: Commit**

```bash
git add discord-bot/bot.py
git commit -m "feat(bot): fire repository_dispatch from /approve and /retry slash commands"
```

---

### Task 10: Wire `gh_dispatch` into feedback modal (comment + request changes)

**Files:**
- Modify: `discord-bot/bot.py`
- Modify: `discord-bot/tests/test_interactions.py`

- [ ] **Step 1: Write the failing test**

In `discord-bot/tests/test_interactions.py`, add to `TestFeedbackModal`:

```python
    @patch("bot.gh_dispatch")
    @patch("bot.gh_command")
    @pytest.mark.asyncio
    async def test_on_submit_fires_reply_dispatch(self, mock_gh, mock_dispatch):
        mock_gh.return_value = (True, "")
        mock_dispatch.return_value = (True, "")
        modal = FeedbackModal(action="comment", issue_number=42, repo="org/repo")
        interaction = AsyncMock(spec=discord.Interaction)
        interaction.response = AsyncMock()
        interaction.followup = AsyncMock()
        interaction.message = AsyncMock()
        interaction.message.embeds = [discord.Embed(title="Test")]
        interaction.user = MagicMock()
        interaction.user.display_name = "jonny"
        interaction.user.id = 123
        modal.feedback = MagicMock()
        modal.feedback.value = "This looks good but needs more tests"
        await modal.on_submit(interaction)
        mock_dispatch.assert_called_once_with("org/repo", "agent-reply", 42)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/test_interactions.py::TestFeedbackModal::test_on_submit_fires_reply_dispatch -v
```

Expected: FAIL — `gh_dispatch` not called

- [ ] **Step 3: Add dispatch call to `FeedbackModal.on_submit`**

In `discord-bot/bot.py`, in the `FeedbackModal.on_submit` method, add the dispatch call after the comment succeeds and the embed is updated, just before the final followup message. The full method should read:

```python
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
        log.info("MODAL: %s on #%d by %s (id=%s)", self.action, self.issue_number, interaction.user, interaction.user.id)
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/test_interactions.py::TestFeedbackModal -v
```

Expected: all pass

- [ ] **Step 5: Commit**

```bash
git add discord-bot/bot.py discord-bot/tests/test_interactions.py
git commit -m "feat(bot): fire agent-reply dispatch from feedback modal"
```

---

### Task 11: Wire `gh_dispatch` into `/comment` slash command

**Files:**
- Modify: `discord-bot/bot.py`

- [ ] **Step 1: Update `/comment` slash command**

In the `cmd_comment` function inside `register_slash_commands`, add the dispatch call after the successful comment:

```python
    async def cmd_comment(interaction: discord.Interaction, issue: int, text: str):
        if not _check_slash_auth(interaction):
            return await interaction.response.send_message("Permission denied.", ephemeral=True)
        await interaction.response.defer(ephemeral=True)
        ok, err = gh_command(["issue", "comment", str(issue), "--repo", REPO, "--body", sanitize_input(text)])
        if not ok:
            await interaction.followup.send(f"Failed to comment on #{issue}: {err}", ephemeral=True)
            return
        gh_dispatch(REPO, "agent-reply", issue)
        await interaction.followup.send(f"Comment posted on #{issue}.", ephemeral=True)
        log.info("SLASH: /comment #%d by %s", issue, interaction.user)
```

- [ ] **Step 2: Run full test suite to verify nothing is broken**

```bash
cd discord-bot && .venv/bin/python -m pytest tests/ -v
```

Expected: all pass

- [ ] **Step 3: Commit**

```bash
git add discord-bot/bot.py
git commit -m "feat(bot): fire agent-reply dispatch from /comment slash command"
```

---

### Task 12: Deploy standalone dispatch workflow to Webber

**Files:**
- Create: `~/repos/Webber/.github/workflows/agent-dispatch.yml` (derived from standalone template)

- [ ] **Step 1: Generate the workflow from the template**

Copy the standalone template and replace `{{BOT_USER}}` with `pennyworth-bot`:

```yaml
name: "Claude Agent: Discord Dispatch"

on:
  repository_dispatch:
    types: [agent-triage, agent-implement, agent-reply]

concurrency:
  group: claude-agent-${{ github.event.client_payload.issue_number }}
  cancel-in-progress: false

jobs:
  triage:
    if: github.event.action == 'agent-triage'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (triage)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            new_issue \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"

  implement:
    if: github.event.action == 'agent-implement'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (implement)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            implement \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"

  reply:
    if: github.event.action == 'agent-reply'
    runs-on: [self-hosted, agent]
    timeout-minutes: 125
    permissions:
      contents: write
      issues: write
      pull-requests: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run agent dispatch (reply)
        env:
          GH_TOKEN: ${{ secrets.AGENT_PAT }}
          GITHUB_TOKEN: ${{ secrets.AGENT_PAT }}
          AGENT_CONFIG: ${{ github.workspace }}/.agent-dispatch/config.env
        run: |
          .agent-dispatch/scripts/agent-dispatch.sh \
            issue_reply \
            "${{ github.repository }}" \
            "${{ github.event.client_payload.issue_number }}"
```

- [ ] **Step 2: Commit and push to Webber**

```bash
cd ~/repos/Webber
git add .github/workflows/agent-dispatch.yml
git commit -m "feat: add discord dispatch workflow for bot-triggered agent actions"
git push
```

---

### Task 13: End-to-end verification

- [ ] **Step 1: Restart the Discord bot service**

```bash
systemctl --user restart agent-dispatch-bot
journalctl --user -u agent-dispatch-bot --since "1 minute ago" --no-pager
```

Verify: Bot connects to Discord gateway without errors.

- [ ] **Step 2: Test the dispatch API manually**

```bash
gh api repos/Frightful-Games/Webber/dispatches \
  -f event_type=agent-implement \
  -f 'client_payload[issue_number]=84'
```

Verify: Check GitHub Actions tab — a "Claude Agent: Discord Dispatch" workflow run should appear for the `implement` job.

- [ ] **Step 3: Test via Discord**

Create a test issue, add the `agent` label manually to trigger triage, wait for `agent:plan-review`, then click Approve in Discord. Verify:
- Discord shows "Approved by [name]"
- `agent:plan-approved` label is added to the issue
- The implement workflow triggers via the dispatch event
- The agent begins implementation

- [ ] **Step 4: Run full test suites**

```bash
cd ~/claude-agent-dispatch && .venv/bin/python -m pytest discord-bot/tests/ -v
cd ~/claude-agent-dispatch && shellcheck scripts/*.sh scripts/lib/*.sh
cd ~/claude-agent-dispatch && ./tests/bats/bin/bats tests/
```

Expected: all pass
