#!/usr/bin/env bats
# Tests for scripts/lib/notify.sh

load 'helpers/test_helper'

_source_notify() {
    source "${LIB_DIR}/notify.sh"
}

# ===================================================================
# No-op behavior when unconfigured
# ===================================================================

@test "notify: silently no-ops when AGENT_NOTIFY_DISCORD_WEBHOOK is empty" {
    export AGENT_NOTIFY_DISCORD_WEBHOOK=""
    _source_notify

    run notify "plan_posted" "Test Issue" "https://github.com/test/1" "Plan summary"
    assert_success
    assert_output ""
}

@test "notify: silently no-ops when AGENT_NOTIFY_DISCORD_WEBHOOK is unset" {
    unset AGENT_NOTIFY_DISCORD_WEBHOOK
    _source_notify

    run notify "plan_posted" "Test Issue" "https://github.com/test/1" "Plan summary"
    assert_success
    assert_output ""
}
