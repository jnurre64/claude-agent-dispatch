#!/bin/bash
# ─── Review gates: adversarial plan review + post-implementation review ──
# Provides: run_adversarial_plan_review, run_post_impl_review,
#           handle_post_impl_review_retry

# ─── Gate A: Adversarial Plan Review ────────────────────────────
# Runs a fresh Claude session to check the plan against the issue.
# Returns 0 to proceed, 1 to halt implementation.
# Side effects: may update AGENT_PLAN_CONTENT (if corrected),
#               may post issue comment, may set labels.
run_adversarial_plan_review() {
    if [ "${AGENT_ADVERSARIAL_PLAN_REVIEW}" != "true" ]; then
        log "Adversarial plan review: skipped (disabled)"
        return 0
    fi

    log "Running adversarial plan review..."
    local prompt
    prompt=$(load_prompt "adversarial-plan" "${AGENT_PROMPT_ADVERSARIAL_PLAN}")

    local result
    result=$(run_claude "$prompt" "$AGENT_ALLOWED_TOOLS_TRIAGE")

    local claude_output
    claude_output=$(parse_claude_output "$result")
    log "Adversarial review result: ${claude_output:0:500}"

    # Parse the action from the response
    # claude_output is the result string from parse_claude_output, which may be
    # a JSON object directly, or a JSON string that needs to be decoded.
    local action
    set +e
    action=$(echo "$claude_output" | jq -r '.action // empty' 2>/dev/null || echo "")
    set -e

    case "$action" in
        approved)
            log "Adversarial plan review: approved"
            return 0
            ;;
        corrected)
            log "Adversarial plan review: corrections made"
            local corrections revised_plan
            corrections=$(echo "$claude_output" | jq -r '.corrections[]' 2>/dev/null | sed 's/^/- /')
            revised_plan=$(echo "$claude_output" | jq -r '.revised_plan // empty' 2>/dev/null)

            if [ -n "$revised_plan" ]; then
                export AGENT_PLAN_CONTENT="$revised_plan"
            fi

            gh issue comment "$NUMBER" --repo "$REPO" --body "<!-- agent-adversarial-review -->
## Adversarial Plan Review: Minor Corrections

The pre-implementation review found minor inconsistencies between the plan and the issue. The following corrections were applied automatically:

${corrections}

Implementation will proceed with the corrected plan." 2>/dev/null || true

            return 0
            ;;
        needs_clarification)
            log "Adversarial plan review: needs clarification"
            local questions
            questions=$(echo "$claude_output" | jq -r '.questions[]' 2>/dev/null | sed 's/^/- /')

            gh issue comment "$NUMBER" --repo "$REPO" --body "<!-- agent-adversarial-review -->
## Adversarial Plan Review: Clarification Needed

The pre-implementation review found ambiguities that need to be resolved before implementation can proceed:

${questions}

Please respond to these questions. Implementation will resume after clarification." 2>/dev/null || true

            set_label "agent:needs-info"
            return 1
            ;;
        *)
            log "Adversarial plan review: could not parse response"
            log "Raw output: $claude_output"
            set_label "agent:failed"
            gh issue comment "$NUMBER" --repo "$REPO" \
                --body "Agent adversarial plan review could not parse its output. Please re-label with \`agent:plan-approved\` to retry." 2>/dev/null || true
            return 1
            ;;
    esac
}
