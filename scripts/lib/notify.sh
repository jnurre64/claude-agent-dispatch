#!/bin/bash
# ─── Discord notification layer (optional) ─────────────────────────
# Sends Discord webhook notifications at dispatch milestones.
# Silently no-ops if AGENT_NOTIFY_DISCORD_WEBHOOK is not configured.

# ─── Notification level check ──────────────────────────────────────
# Returns 0 (true) if the event should be sent at the current level.
_notify_should_send() {
    local event_type="$1"
    local level="${AGENT_NOTIFY_LEVEL:-actionable}"

    case "$level" in
        all)
            return 0
            ;;
        actionable)
            case "$event_type" in
                plan_posted|questions_asked|pr_created|review_feedback|agent_failed)
                    return 0 ;;
                *)
                    return 1 ;;
            esac
            ;;
        failures)
            case "$event_type" in
                tests_failed|agent_failed)
                    return 0 ;;
                *)
                    return 1 ;;
            esac
            ;;
        *)
            return 0
            ;;
    esac
}

# ─── Main notification function ────────────────────────────────────
# Usage: notify <event_type> <title> <url> [description]
#
# Event types: plan_posted, questions_asked, implement_started,
#              tests_passed, tests_failed, pr_created,
#              review_feedback, agent_failed
notify() {
    local event_type="${1:-}"
    local title="${2:-}"
    local url="${3:-}"
    local description="${4:-}"

    # No-op if webhook not configured
    [ -z "${AGENT_NOTIFY_DISCORD_WEBHOOK:-}" ] && return 0

    # Check notification level filter
    _notify_should_send "$event_type" || return 0

    local json
    json=$(_notify_build_embed "$event_type" "$title" "$url" "$description")

    _notify_send "$json"
}
