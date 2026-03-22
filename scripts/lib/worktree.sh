#!/bin/bash
# ─── Git worktree management ────────────────────────────────────

# Ensure the base repo is cloned and up to date.
ensure_repo() {
    if [ ! -d "$REPO_DIR/.git" ]; then
        log "Cloning $REPO..."
        git clone "https://github.com/${REPO}.git" "$REPO_DIR"
    fi
    git -C "$REPO_DIR" fetch origin --prune 2>/dev/null || true
}

# Create a fresh worktree for the current issue/PR.
# If the branch exists on remote, checks it out; otherwise creates from origin/main.
setup_worktree() {
    # Remove existing worktree at our target path
    if [ -d "$WORKTREE_DIR" ]; then
        git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
    fi

    # Prune stale worktree references (e.g., from crashed previous runs)
    git -C "$REPO_DIR" worktree prune 2>/dev/null || true

    # Delete local branch if it exists
    git -C "$REPO_DIR" branch -D "$BRANCH_NAME" 2>/dev/null || true

    # Fetch latest to ensure we have current main and know if remote branch exists
    git -C "$REPO_DIR" fetch origin --prune 2>/dev/null || true

    # Check if branch exists on remote
    if git -C "$REPO_DIR" ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
        git -C "$REPO_DIR" worktree add "$WORKTREE_DIR" -B "$BRANCH_NAME" "origin/$BRANCH_NAME"
    else
        git -C "$REPO_DIR" worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" origin/main
    fi
}

# Remove the worktree for the current issue/PR.
cleanup_worktree() {
    git -C "$REPO_DIR" worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
}
# Test change for update verification
