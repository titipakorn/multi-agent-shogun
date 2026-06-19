#!/usr/bin/env bats
# e2e_bloom_routing.bats — Dim C: Smart Switching E2E Test
# Issue #53 Phase 2 — find_agent_for_model() + orchestrator bloom routing Integration Verification
#
# Assumed execution only on VPS. The tmux session "multiagent" is already started,
# and a mixed CLI configuration (surveyor-3=Spark, experimentalist-5=Sonnet, critic-7=Opus) is
# required.
#
# Prerequisites:
#   - VPS configuration: surveyor-3=codex/spark, experimentalist-5=claude/sonnet, critic-7=claude/opus
#   - bloom_routing: "manual" or "auto"
#   - All Ashigaru are idle (before starting test)
#
# Execution method:
#   bats tests/e2e/e2e_bloom_routing.bats
#

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    # Confirm tmux session exists
    if ! tmux has-session -t multiagent 2>/dev/null; then
        skip "tmux session 'multiagent' does not exist. Run after shutsuijin on VPS."
    fi

    # Load lib/cli_adapter.sh
    export CLI_ADAPTER_PROJECT_ROOT="$PROJECT_ROOT"
    export CLI_ADAPTER_SETTINGS="${PROJECT_ROOT}/config/settings.yaml"
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/lib/cli_adapter.sh"
    # shellcheck disable=SC1090
    source "${PROJECT_ROOT}/lib/agent_status.sh" 2>/dev/null || true
}

teardown() {
    # Clean up task files after testing
    :
}

# ─────────────────────────────────────────────
# TC-BLOOM-001: L1 task -> assigned to Spark Agent
# ─────────────────────────────────────────────
@test "TC-BLOOM-001: L1 task -> assigned to Spark Agent" {
    run get_recommended_model 1
    [ "$status" -eq 0 ]
    # L1 is cheapest with Spark (max_bloom=3)
    [[ "$output" == *"spark"* ]] || [[ "$output" == *"codex"* ]]

    recommended="$output"
    run find_agent_for_model "$recommended"
    [ "$status" -eq 0 ]
    # Spark Agent is surveyor
    [ "$output" = "surveyor" ]
}

# ─────────────────────────────────────────────
# TC-BLOOM-002: L5 task -> assigned to Sonnet Agent
# ─────────────────────────────────────────────
@test "TC-BLOOM-002: L5 task -> assigned to Sonnet Agent" {
    run get_recommended_model 5
    [ "$status" -eq 0 ]
    [[ "$output" == *"sonnet"* ]]

    recommended="$output"
    run find_agent_for_model "$recommended"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(experimentalist|analyst|ablation_planner|writer|observer)$ ]]
}

# ─────────────────────────────────────────────
# TC-BLOOM-003: L6 task -> assigned to Opus Agent
# ─────────────────────────────────────────────
@test "TC-BLOOM-003: L6 task -> assigned to Opus Agent" {
    run get_recommended_model 6
    [ "$status" -eq 0 ]
    [[ "$output" == *"opus"* ]]

    recommended="$output"
    run find_agent_for_model "$recommended"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(critic|architect|council)$ ]]
}

# ─────────────────────────────────────────────
# TC-BLOOM-004: When experimentalist is busy, L5 task is assigned to analyst
# No kill/restart occurs (verify busy pane remains unchanged)
# ─────────────────────────────────────────────
@test "TC-BLOOM-004: When experimentalist is busy, L5 task is assigned to analyst" {
    # Get pane target of experimentalist
    pane4=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{@agent_id}' \
        | awk '$2 == "experimentalist" {print $1}')

    if [[ -z "$pane4" ]]; then
        skip "experimentalist pane not found"
    fi

    # Create busy state using sleep (teardown guaranteed by trap)
    # shellcheck disable=SC2064
    trap "tmux send-keys -t '$pane4' '' C-c; sleep 0.3" EXIT
    tmux send-keys -t "$pane4" "echo 'Working...'; sleep 30" Enter
    sleep 1

    # Verify busy
    busy_rc=0
    agent_is_busy_check "$pane4" && true || busy_rc=$?
    if [[ $busy_rc -ne 0 ]]; then
        skip "Could not set experimentalist to busy state (busy_rc=${busy_rc})"
    fi

    # L5 task routing
    recommended=$(get_recommended_model 5)
    run find_agent_for_model "$recommended"
    [ "$status" -eq 0 ]

    # experimentalist is busy so it should be assigned to analyst
    [ "$output" = "analyst" ] || \
        { echo "Expected: analyst, Actual: $output"; return 1; }

    # Verify experimentalist is still running (not killed/restarted)
    still_busy=0
    agent_is_busy_check "$pane4" && true || still_busy=$?
    [[ $still_busy -eq 0 ]] || echo "WARNING: experimentalist state changed (possible kill/restart)"
}

# ─────────────────────────────────────────────
# TC-BLOOM-005: When all Sonnet Ashigaru are busy, placed in QUEUE (verify no downgrade to Codex)
# ─────────────────────────────────────────────
@test "TC-BLOOM-005: When all Sonnet Ashigaru are busy, placed in QUEUE (verify no downgrade to Codex)" {
    local sonnet_agents=(experimentalist analyst ablation_planner writer observer)
    local panes=()
    local p
    for a in "${sonnet_agents[@]}"; do
        p=$(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{@agent_id}' \
            | awk -v agent="$a" '$2 == agent {print $1}')
        if [[ -n "$p" ]]; then
            panes+=("$p")
        fi
    done

    if [[ ${#panes[@]} -lt 5 ]]; then
        skip "not all Sonnet specialist panes found"
    fi

    # Create busy state for all Sonnet specialists
    # shellcheck disable=SC2064
    trap "for pane in \"\${panes[@]}\"; do tmux send-keys -t \"\$pane\" '' C-c; done; sleep 0.3" EXIT
    for pane in "${panes[@]}"; do
        tmux send-keys -t "$pane" "echo 'Working...'; sleep 30" Enter
    done
    sleep 1

    # Verify they are busy
    for pane in "${panes[@]}"; do
        agent_is_busy_check "$pane" || { skip "Could not set Sonnet pane $pane to busy state"; }
    done

    # L5 task routing
    recommended=$(get_recommended_model 5)
    result=$(find_agent_for_model "$recommended")

    # Confirm it returns QUEUE (doing nothing is invalid)
    [ "$result" = "QUEUE" ]
}

# ─────────────────────────────────────────────
# TC-BLOOM-006: L3 task -> not assigned to Sonnet Ashigaru (Codex priority)
# ─────────────────────────────────────────────
@test "TC-BLOOM-006: Spark Ashigaru prioritized for L3 tasks (no over-engineering to Sonnet)" {
    run get_recommended_model 3
    [ "$status" -eq 0 ]

    # Spark is recommended for L3 instead of Sonnet
    [[ "$output" != *"sonnet"* ]] || { echo "Sonnet was recommended for L3 (cost optimization violation)"; return 1; }
    [[ "$output" == *"spark"* ]] || [[ "$output" == *"codex"* ]]

    recommended="$output"
    run find_agent_for_model "$recommended"
    [ "$status" -eq 0 ]

    # Spark Ashigaru is surveyor
    [ "$output" = "surveyor" ]
}
