#!/usr/bin/env bash
# Constants for the v2 (specialist team) topology.
# Source this from depart.sh.
#
# NOTE: This file is intentionally bash-3.2 compatible (associative arrays
# are a bash-4.0 feature). On macOS the system /bin/bash is still 3.2.
# We provide the same role→{pane,model,color} lookups via case statements.

# ─── Read role list in deterministic order ───────────────────
v2_role_list() {
    echo "shogun orchestrator surveyor critic architect experimentalist analyst ablation_planner writer observer council"
}

# ─── Read pane target for a role ─────────────────────────────
v2_pane_for() {
    local role=$1
    case "$role" in
        shogun)            echo "shogun:main.0" ;;
        orchestrator)      echo "multiagent:ops.0" ;;
        architect)         echo "multiagent:ops.1" ;;
        experimentalist)   echo "multiagent:ops.2" ;;
        analyst)           echo "multiagent:ops.3" ;;
        ablation_planner)  echo "multiagent:ops.4" ;;
        surveyor)          echo "multiagent:research.0" ;;
        critic)            echo "multiagent:research.1" ;;
        writer)            echo "multiagent:research.2" ;;
        observer)          echo "multiagent:research.3" ;;
        council)           echo "multiagent:research.4" ;;
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