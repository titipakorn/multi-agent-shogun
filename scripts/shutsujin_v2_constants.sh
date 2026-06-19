#!/usr/bin/env bash
# Constants for the v2 (specialist team) topology.
# Source this from depart.sh.
#
# NOTE: This file is intentionally bash-3.2 compatible (associative arrays
# are a bash-4.0 feature). On macOS the system /bin/bash is still 3.2.
# We provide the same role→{pane,model,color} lookups via case statements.

# ─── Load session suffix ─────────────────────────────────────
agent_registry_load_session_suffix() {
    [ -n "${SHOGUN_SESSION_SUFFIX:-}" ] && return 0

    local settings_file=""
    if [ -f "./config/settings.yaml" ]; then
        settings_file="./config/settings.yaml"
    elif [ -n "${AGENT_REGISTRY_PROJECT_ROOT:-}" ] && [ -f "${AGENT_REGISTRY_PROJECT_ROOT}/config/settings.yaml" ]; then
        settings_file="${AGENT_REGISTRY_PROJECT_ROOT}/config/settings.yaml"
    elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../config/settings.yaml" ]; then
        settings_file="$(dirname "${BASH_SOURCE[0]}")/../config/settings.yaml"
    fi

    if [ -n "$settings_file" ] && [ -f "$settings_file" ]; then
        local suffix_setting
        suffix_setting=$(grep "^session_suffix:" "$settings_file" 2>/dev/null | awk '{print $2}' | tr -d '"'\'' ' || echo "")
        if [ "$suffix_setting" = "auto" ]; then
            local dir_name
            dir_name=$(basename "$(pwd)")
            SHOGUN_SESSION_SUFFIX="-$(echo "$dir_name" | tr -cd 'A-Za-z0-9_-')"
        else
            SHOGUN_SESSION_SUFFIX="$suffix_setting"
        fi
    else
        SHOGUN_SESSION_SUFFIX=""
    fi
    export SHOGUN_SESSION_SUFFIX
}
agent_registry_load_session_suffix

# ─── Read role list in deterministic order ───────────────────
v2_role_list() {
    echo "shogun orchestrator surveyor critic architect experimentalist analyst ablation_planner writer observer council"
}

# ─── Read pane target for a role ─────────────────────────────
v2_pane_for() {
    local role=$1
    local suffix="${SHOGUN_SESSION_SUFFIX:-}"
    case "$role" in
        shogun)            echo "shogun${suffix}:main.0" ;;
        orchestrator)      echo "multiagent${suffix}:ops.0" ;;
        architect)         echo "multiagent${suffix}:ops.1" ;;
        experimentalist)   echo "multiagent${suffix}:ops.2" ;;
        analyst)           echo "multiagent${suffix}:ops.3" ;;
        ablation_planner)  echo "multiagent${suffix}:ops.4" ;;
        surveyor)          echo "multiagent${suffix}:research.0" ;;
        critic)            echo "multiagent${suffix}:research.1" ;;
        writer)            echo "multiagent${suffix}:research.2" ;;
        observer)          echo "multiagent${suffix}:research.3" ;;
        council)           echo "multiagent${suffix}:research.4" ;;
        *)                 echo "" ;;
    esac
}

# ─── Read model for a role ───────────────────────────────────
v2_model_for() {
    local role=$1
    case "$role" in
        shogun|orchestrator|critic|architect|council) echo "opus" ;;
        surveyor)                                    echo "haiku" ;;
        experimentalist|analyst|ablation_planner|writer|observer) echo "sonnet" ;;
        *)                                           echo "sonnet" ;;
    esac
}

# ─── Read color for a role ───────────────────────────────────
v2_color_for() {
    local role=$1
    case "$role" in
        shogun)            echo "#002b36" ;;
        orchestrator)      echo "#501515" ;;
        architect)         echo "#1e3a1e" ;;
        experimentalist)   echo "#1e3a3a" ;;
        analyst)           echo "#3a1e3a" ;;
        ablation_planner)  echo "#503515" ;;
        surveyor)          echo "#454510" ;;
        critic)            echo "#9e7c0a" ;;
        writer)            echo "#353535" ;;
        observer)          echo "#1c2a38" ;;
        council)           echo "#2b2b2b" ;;
        *)                 echo "#303030" ;;
    esac
}

# ─── Parse a session:window.pane target ─────────────────────
# Splits a target like "multiagent:ops.0" into its parts.
# Sets: V2_SESSION, V2_WINDOW, V2_PANE_IDX
v2_split_target() {
    local target=$1
    V2_SESSION="${target%%:*}"
    local rest="${target#*:}"
    V2_WINDOW="${rest%.*}"
    V2_PANE_IDX="${rest##*.}"
}