# Rename `claude-agent-dispatch` → `claude-pal-action` — Design

**Status:** Design approved, ready for implementation plan
**Date:** 2026-04-18

## Problem

Two motivations drive this rename:

1. **Product collision with Anthropic's "Claude Dispatch."** Anthropic shipped Claude Dispatch on 2026-03-17 as part of Claude Cowork — a persistent mobile↔desktop conversation thread. The name "claude-agent-dispatch" now confuses users who assume a relationship to the official product. There is none.
2. **Brand alignment with sibling project `claude-pal`.** A separate, lightweight, local-only variant lives at `~/repos/claude-pal/` (`jnurre64/claude-pal`, currently v0.x). It runs Claude Code containers against GitHub issues on the host machine without GitHub Actions. Renaming this repo to `claude-pal-action` establishes a clear two-product family: `claude-pal` (local) and `claude-pal-action` (GitHub Actions–driven).

The `-action` suffix is a soft GitHub naming convention typically associated with repos that ship `action.yml` (composite/Docker/JS Actions). This repo ships **reusable workflows** instead. The mismatch is acknowledged and accepted — see [Non-goals](#non-goals).

## Goals

1. Rename the GitHub repo `jnurre64/claude-agent-dispatch` → `jnurre64/claude-pal-action`.
2. Update all in-repo self-references (README badges, clone URLs, security advisory links, setup scripts, skill templates, plan/spec doc cross-references) so the visible identity matches the new name.
3. Update the primary production consumer (`Frightful-Games/Webber`) eagerly. Other consumers ride GitHub URL redirects until their next `/update` skill run.
4. Migrate the local clone on the dispatch host (`~/claude-agent-dispatch/` → `~/repos/claude-pal-action/`) and update the two systemd services that reference it, without bot downtime exceeding ~1 minute.
5. Preserve all existing tags (`v1.0.0`–`v1.2.0`, floating `v1`), branch protection, secrets, fine-grained PAT scopes, and webhooks.
6. Keep the rename non-breaking for downstream consumers via GitHub's URL redirects. No version bump.

## Non-goals

- **Restructure into a true GitHub Action with `action.yml`.** Reusable workflows are the correct architectural fit for this system: each phase (`triage`, `implement`, `reply`, `review`, `direct-implement`) needs distinct job-level permissions, distinct concurrency keys, and distinct runner-label routing. Composite actions cannot express these (they run as steps inside the caller's job, inheriting the caller's runner and permissions). Collapsing five phases into one `action.yml` with a `phase:` input would harm maintainability. The `-action` suffix here reads as plain English ("the GitHub Action variant"), not as a structural promise.
- **Rename systemd unit names** (`agent-dispatch-bot.service`, `agent-dispatch-slack.service`). These describe the service's *function* (dispatching agents), not the repo it lives in. Renaming would churn `systemctl` muscle memory and any logs/dashboards keyed on the unit name. Only `WorkingDirectory=` changes.
- **Rename Discord/Slack bot identities** (`pennyworth-bot` GitHub account, "Pennyworth" Discord/Slack app names). The bot brand is independent of the repo brand.
- **Rename the consumer-side `.agent-dispatch/` directory convention.** It describes function, not upstream identity, and keeps consumers portable.
- **Update demo repos** (`dodge-the-creeps-demo`, `recipe-manager-demo`, `recipe-manager-setup-demo`) eagerly. They ride redirects until their next `/update` run.
- **Bump major version.** The rename is non-breaking thanks to GitHub redirects. Stay on `v1.x`; bump `v1.3.0` whenever the next actual feature lands. Add a `CHANGELOG.md` entry noting the rename date.
- **Update the `~/agent-infra/` clone-path suggestion in public docs.** Keep public setup docs path-agnostic; only the local layout on this host changes.

## Scope

### What gets renamed (eager)

| Target | Mechanism |
|---|---|
| GitHub repo | Settings → Rename |
| In-repo self-references (~533 occurrences across ~120 files) | `git grep` + targeted `sed`, diff-reviewed per file. **Historical references** in `docs/superpowers/plans/*.md` and `docs/plans/*.md` documenting prior PRs/issues against the old name are intentionally **left as-is** (they are history, not active references). |
| Webber consumer (`~/repos/Webber`) | `.agent-dispatch/.upstream`, `.agent-dispatch/scripts/setup.sh` echoed text, `.git/COMMIT_EDITMSG` template, `docs/plans/agent-infra-repo.md`, `caller-dispatch.yml` workflow `uses:` ref |
| Local clone path | `mv ~/claude-agent-dispatch ~/repos/claude-pal-action` |
| Local origin remote | `git remote set-url origin git@github.com-infra:jnurre64/claude-pal-action.git` |
| Bot venvs | Recreated in place after the move (Python venv `bin/` shebangs hardcode absolute paths) |
| Systemd `WorkingDirectory=` | `~/.config/systemd/user/agent-dispatch-{bot,slack}.service` |
| Memory files | 5 entries; `project_claude_agent_dispatch.md` renamed to `project_claude_pal_action.md`; `MEMORY.md` index updated |

### What does NOT get renamed (deliberate)

- Bot accounts and Discord/Slack app identities (`pennyworth-bot`, "Pennyworth")
- Systemd unit names
- Demo repos (lazy via `/update`)
- Existing tags
- Branch protection ruleset (follows the rename automatically)
- Secrets, webhooks, fine-grained PAT scopes (GitHub tracks these by repo ID)
- Label namespace (`agent:*`)
- `.agent-dispatch/` directory convention in consumer repos
- `~/agent-infra/` clone-path suggestion in public docs

## Migration sequence

Order is load-bearing — Phase 1 stages a small visible-identity PR that depends on the GitHub rename in Phase 2 already having happened.

### Phase 0 — Preflight (10 min, fully reversible)

1. Verify `dispatch-cli-token` PAT in GitHub Settings still lists the repo. Capture a screenshot of the repository-access list for rollback reference.
2. Snapshot pre-rename state:
   - `git rev-parse HEAD` in `~/claude-agent-dispatch` and `~/repos/Webber`
   - `gh pr list --repo jnurre64/claude-agent-dispatch` and `gh issue list --repo jnurre64/claude-agent-dispatch`
   - `cp ~/.config/systemd/user/agent-dispatch-bot.service /tmp/rename-snapshot/`
   - `cp ~/.config/systemd/user/agent-dispatch-slack.service /tmp/rename-snapshot/`
   - `systemctl --user status agent-dispatch-bot agent-dispatch-slack > /tmp/rename-snapshot/services-before.txt`
3. Confirm no in-flight agent runs: no open `agent:in-progress` labels on any consumer repo, no active workflow runs in GitHub Actions UI.

### Phase 1 — Spec branch (this commit)

This design document is committed on branch `spec/rename-to-claude-pal-action` *before* the GitHub rename so it survives the cutover cleanly under the new repo name. Branch refs are content-addressed and unaffected by repo rename.

### Phase 2 — GitHub rename (the cutover moment)

1. GitHub Settings → Repository name → `claude-pal-action` → Rename.
2. Within 30 seconds verify:
   - `gh repo view jnurre64/claude-pal-action` succeeds
   - `gh repo view jnurre64/claude-agent-dispatch` redirects (returns the new repo)
   - `git fetch` from local clone (pre-move) still works via redirect
3. **Recovery path if anything looks wrong**: rename back via Settings. New redirect is created in the reverse direction. PAT, branch protection, secrets all follow back. Total recovery time: ~5 minutes. The rename is not a one-way door.

### Phase 2.5 — Visible-identity PR (clean cutover)

A minimal PR (~15-30 lines) updating only the user-visible identity surface, merged immediately after the rename:

- README badges (CI, release, license — all GitHub URLs)
- README clone-URL examples
- `SECURITY.md` advisory link
- `scripts/setup.sh` echoed help text (lines 161, 360)
- `.github/ISSUE_TEMPLATE/config.yml` docs URL

Goal: repo's visible identity matches its new name within minutes of the rename. The larger 500+ occurrence sweep moves to Phase 4.5 with no time pressure.

### Phase 3 — Local clone migration

1. Stop bot services briefly:
   ```bash
   systemctl --user stop agent-dispatch-bot agent-dispatch-slack
   ```
2. Move the clone:
   ```bash
   mv ~/claude-agent-dispatch ~/repos/claude-pal-action
   ```
3. Update origin:
   ```bash
   cd ~/repos/claude-pal-action
   git remote set-url origin git@github.com-infra:jnurre64/claude-pal-action.git
   git fetch && git status
   ```
4. Recreate bot venvs (Python venvs hardcode absolute paths in `bin/` shebangs):
   ```bash
   cd ~/repos/claude-pal-action/discord-bot
   rm -rf .venv && python -m venv .venv && .venv/bin/pip install -r requirements.txt
   cd ~/repos/claude-pal-action/slack-bot
   rm -rf .venv && python -m venv .venv && .venv/bin/pip install -r requirements.txt
   ```
5. Update systemd unit `WorkingDirectory=` lines in:
   - `~/.config/systemd/user/agent-dispatch-bot.service`
   - `~/.config/systemd/user/agent-dispatch-slack.service`
6. Reload and restart:
   ```bash
   systemctl --user daemon-reload
   systemctl --user start agent-dispatch-bot agent-dispatch-slack
   systemctl --user status agent-dispatch-bot agent-dispatch-slack
   ```
7. Smoke-test: post a benign comment on a Frightful-Games demo issue that should trigger a notification; verify both Discord and Slack receive it.

Bot downtime budget: ~1 minute (steps 1–6).

### Phase 4 — Webber consumer update

1. In `~/repos/Webber`, branch `chore/rename-claude-pal-action`.
2. Update:
   - `.agent-dispatch/.upstream` — repo URL
   - `.agent-dispatch/scripts/setup.sh` — echoed text (lines 154, 342)
   - `.git/COMMIT_EDITMSG` template comment
   - `docs/plans/agent-infra-repo.md` — all `jnurre64/claude-agent-dispatch` references
   - `caller-dispatch.yml` workflow file: `uses: jnurre64/claude-pal-action/.github/workflows/dispatch-*.yml@v1`
3. End-to-end smoke test: label a throwaway issue with `agent:triage` on a demo repo (NOT Webber's main issues), verify the workflow runs and the bot responds.
4. Open PR, merge.

### Phase 4.5 — Bulk in-repo doc sweep (low-pressure)

Branch `chore/rename-doc-sweep`. The remaining ~500 occurrences across docs/plans, .claude/skills, and other internal references. Approach:

```bash
git grep -l 'claude-agent-dispatch' \
  | grep -v '^docs/superpowers/plans/' \
  | grep -v '^docs/superpowers/specs/' \
  | grep -v '^docs/plans/' \
  | xargs sed -i 's|jnurre64/claude-agent-dispatch|jnurre64/claude-pal-action|g; s|claude-agent-dispatch|claude-pal-action|g'
```

Then **diff-review every changed file** before committing — some occurrences may need manual handling (e.g., places where "agent dispatch" as a noun phrase appears without `claude-` prefix). Historical references in `docs/superpowers/plans/`, `docs/superpowers/specs/`, and `docs/plans/` are deliberately excluded — they document prior PRs and issues against the old name (including this spec's own problem statement) and should remain accurate as history.

Verify CI green (BATS + ShellCheck), open PR, merge.

### Phase 5 — Memory updates

Update on this machine:

| File | Action |
|---|---|
| `~/.claude/projects/-home-jonny/memory/project_claude_agent_dispatch.md` | Rename to `project_claude_pal_action.md`; update repo URL, paths, and `name`/`description` frontmatter |
| `~/.claude/projects/-home-jonny/memory/project_dispatch_notify.md` | Update repo references |
| `~/.claude/projects/-home-jonny/memory/reference_github_finegrained_pat_collaborator.md` | Update PAT-scope repo references |
| `~/.claude/projects/-home-jonny/memory/reference_dispatch_host_services.md` | Update `WorkingDirectory` paths and clone path |
| `~/.claude/projects/-home-jonny/memory/MEMORY.md` | Update index entry filename and one-line hook |

Add new memory entry: **"Reserved name: `jnurre64/claude-agent-dispatch`** — do not create a new repo with this name. Doing so breaks the GitHub redirect that ~4 active references depend on (Webber `caller-dispatch.yml`, three demo repos via `/update` propagation, public clone URLs in old social/blog posts)."

### Phase 6 — Cleanup

After 24h of healthy bot operation:
- Delete `/tmp/rename-snapshot/`.
- Close the design's tracking issue (if one was opened).

## Risk register

| Risk | Likelihood | Detection | Mitigation / Rollback |
|---|---|---|---|
| `dispatch-cli-token` PAT loses access after rename | Low — GitHub tracks by repo ID | `gh issue list --repo jnurre64/claude-pal-action` with token override returns 401/404 | Re-add repo to PAT scope at github.com/settings/personal-access-tokens. PAT itself doesn't need regeneration. |
| Systemd service fails after path move | Medium — venv path issues | `systemctl --user status` shows failed; bot stops responding | Phase 0 snapshot makes revert one `cp` + `daemon-reload` away. Old clone path can be restored with `mv` in reverse. |
| In-flight agent run during rename | Low — controlled timing | Phase 0 preflight | Delay Phase 2 until current run completes. |
| Webber workflow breaks before Phase 4 | Medium if Phase 4 delayed | Workflow run fails | Webber's `uses:` ref keeps resolving via redirect. Phase 4 is "should do soon," not "must do immediately." |
| Demo repos break before next `/update` | Low | Demo workflow runs fail | Same redirect-based fallback. Demos are test infrastructure. |
| Someone creates a new repo at the old name | Low but permanent | Old URL stops redirecting | Memory entry added in Phase 5 to reserve the name. |
| Branch protection ruleset doesn't follow rename | Very low | Push to main succeeds without PR | Re-create from repo settings UI. |
| Discord/Slack config references break | Low | Bot logs error on startup | `~/agent-infra/config.env` is path-independent; only systemd `WorkingDirectory=` references the path (Phase 3). |

## Success criteria

1. `gh repo view jnurre64/claude-pal-action` returns the renamed repo.
2. `gh repo view jnurre64/claude-agent-dispatch` redirects (returns the new repo).
3. CI on `main` is green after Phase 2.5 and Phase 4.5 PRs merge.
4. Both bot services healthy (`systemctl --user status` shows `active (running)`) and demonstrably routing notifications after Phase 3.
5. Webber agent workflow runs end-to-end against a test issue after Phase 4.
6. All five memory files updated; `MEMORY.md` index reflects the new filename.
7. Tags `v1.0.0`–`v1.2.0` and floating `v1` resolve under both old and new repo URLs.

## Out of scope (potential follow-ups, not part of this work)

- Adding a thin top-level `action.yml` composite that wraps the most common single-phase flow for users who prefer Action syntax. Purely additive; can land any time.
- Migrating demo repos eagerly via direct PR rather than waiting for `/update` (low value; demos are test infra).
- Marketplace listing on github.com/marketplace (would require `action.yml`).
