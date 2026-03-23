#!/usr/bin/env bats
# Tests for scripts/lib/worktree.sh (source-level verification)
# Note: worktree operations require real git repos. These tests verify
# the source code structure rather than running git commands.

load 'helpers/test_helper'

@test "worktree.sh: defines ensure_repo function" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/worktree.sh"
    declare -f ensure_repo > /dev/null
}

@test "worktree.sh: defines setup_worktree function" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/worktree.sh"
    declare -f setup_worktree > /dev/null
}

@test "worktree.sh: defines cleanup_worktree function" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/worktree.sh"
    declare -f cleanup_worktree > /dev/null
}

@test "worktree.sh: setup_worktree prunes stale worktrees" {
    grep -q "worktree prune" "${LIB_DIR}/worktree.sh"
}

@test "worktree.sh: setup_worktree checks for remote branch before creating" {
    grep -q "ls-remote.*heads.*BRANCH_NAME" "${LIB_DIR}/worktree.sh"
}

@test "worktree.sh: cleanup_worktree uses --force" {
    grep -q "worktree remove.*--force" "${LIB_DIR}/worktree.sh"
}

@test "worktree.sh: defines run_worktree_setup function" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/worktree.sh"
    declare -f run_worktree_setup > /dev/null
}

@test "worktree.sh: run_worktree_setup runs AGENT_TEST_SETUP_COMMAND when set" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/worktree.sh"
    export AGENT_TEST_SETUP_COMMAND="echo setup_ran"
    export WORKTREE_DIR="$TEST_TEMP_DIR/worktree"

    run run_worktree_setup
    assert_success
    assert_output --partial "setup_ran"
}

@test "worktree.sh: run_worktree_setup no-ops when AGENT_TEST_SETUP_COMMAND is empty" {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/worktree.sh"
    export AGENT_TEST_SETUP_COMMAND=""
    export WORKTREE_DIR="$TEST_TEMP_DIR/worktree"

    run run_worktree_setup
    assert_success
    assert_output ""
}

@test "worktree.sh: setup_worktree calls run_worktree_setup" {
    grep -q "run_worktree_setup" "${LIB_DIR}/worktree.sh"
}
