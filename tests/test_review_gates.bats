#!/usr/bin/env bats
# Tests for scripts/lib/review-gates.sh

load 'helpers/test_helper'

# Helper to source review-gates.sh (requires common.sh first)
_source_review_gates() {
    source "${LIB_DIR}/common.sh"
    source "${LIB_DIR}/review-gates.sh"
}

# ═══════════════════════════════════════════════════════════════
# run_adversarial_plan_review — Gate A
# ═══════════════════════════════════════════════════════════════

@test "Gate A: skipped when AGENT_ADVERSARIAL_PLAN_REVIEW=false" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="false"
    _source_review_gates

    run run_adversarial_plan_review
    assert_success

    # run_claude should never have been called — no mock_calls file
    [ ! -f "${TEST_TEMP_DIR}/mock_calls_timeout" ]
}

@test "Gate A: approved response returns 0" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="true"
    export AGENT_PLAN_CONTENT="Test plan"
    _source_review_gates

    # Mock run_claude to return approved
    run_claude() {
        echo '{"result":"{\"action\": \"approved\"}"}'
    }

    run run_adversarial_plan_review
    assert_success
}

@test "Gate A: corrected response returns 0 and updates AGENT_PLAN_CONTENT" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="true"
    export AGENT_PLAN_CONTENT="Original plan"
    create_mock "gh" ""
    _source_review_gates

    # Mock run_claude to return corrected
    run_claude() {
        echo '{"result":"{\"action\": \"corrected\", \"corrections\": [\"Fixed metric\"], \"revised_plan\": \"Corrected plan\"}"}'
    }

    run_adversarial_plan_review
    assert_equal "$AGENT_PLAN_CONTENT" "Corrected plan"
}

@test "Gate A: corrected response posts comment with marker" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="true"
    export AGENT_PLAN_CONTENT="Original plan"
    create_mock "gh" ""
    _source_review_gates

    run_claude() {
        echo '{"result":"{\"action\": \"corrected\", \"corrections\": [\"Fixed metric\"], \"revised_plan\": \"Corrected plan\"}"}'
    }

    run_adversarial_plan_review
    local calls
    calls=$(get_mock_calls "gh")
    [[ "$calls" == *"agent-adversarial-review"* ]]
}

@test "Gate A: needs_clarification response returns 1" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="true"
    export AGENT_PLAN_CONTENT="Test plan"
    create_mock "gh" ""
    _source_review_gates

    run_claude() {
        echo '{"result":"{\"action\": \"needs_clarification\", \"questions\": [\"What does X mean?\"]}"}'
    }

    run run_adversarial_plan_review
    assert_failure
}

@test "Gate A: needs_clarification sets agent:needs-info label" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="true"
    export AGENT_PLAN_CONTENT="Test plan"
    create_mock "gh" ""
    _source_review_gates

    run_claude() {
        echo '{"result":"{\"action\": \"needs_clarification\", \"questions\": [\"What does X mean?\"]}"}'
    }

    run_adversarial_plan_review || true
    local calls
    calls=$(get_mock_calls "gh")
    [[ "$calls" == *"agent:needs-info"* ]]
}

@test "Gate A: malformed JSON returns 1 and sets agent:failed" {
    export AGENT_ADVERSARIAL_PLAN_REVIEW="true"
    export AGENT_PLAN_CONTENT="Test plan"
    create_mock "gh" ""
    _source_review_gates

    run_claude() {
        echo '{"result":"not valid json at all"}'
    }

    run run_adversarial_plan_review
    assert_failure
    local calls
    calls=$(get_mock_calls "gh")
    [[ "$calls" == *"agent:failed"* ]]
}
