#!/usr/bin/env bats
# agent_registry.sh / watcher_supervisor dynamic formation tests

setup() {
    TEST_TMP="$(mktemp -d)"
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

teardown() {
    rm -rf "$TEST_TMP"
}

write_settings() {
    local path="$1"
    shift
    cat > "$path" << YAML
$*
YAML
}

load_registry_with() {
    export AGENT_REGISTRY_SETTINGS="$1"
    source "$PROJECT_ROOT/lib/agent_registry.sh"
}

join_lines() {
    tr '\n' ' ' | sed 's/ $//'
}

@test "agent_registry: full cli.agents formation preserves configured order" {
    local settings="$TEST_TMP/settings.yaml"
    write_settings "$settings" 'cli:
  default: codex
  agents:
    shogun:
      type: codex
    orchestrator:
      type: codex
    surveyor:
      type: codex
    critic:
      type: codex
    council:
      type: codex'

    load_registry_with "$settings"

    result=$(agent_registry_agents | join_lines)
    [ "$result" = "shogun orchestrator surveyor critic council" ]

    result=$(agent_registry_multiagent_agents | join_lines)
    [ "$result" = "orchestrator surveyor critic council" ]
}

@test "agent_registry: partial override config without orchestrator falls back to legacy formation" {
    local settings="$TEST_TMP/settings.yaml"
    write_settings "$settings" 'cli:
  default: claude
  agents:
    observer: codex
    council: copilot'

    load_registry_with "$settings"

    result=$(agent_registry_multiagent_agents | join_lines)
    [ "$result" = "orchestrator architect experimentalist analyst ablation_planner surveyor critic writer observer council" ]
}

@test "agent_registry: pane mapping follows configured order and pane base" {
    local settings="$TEST_TMP/settings.yaml"
    write_settings "$settings" 'cli:
  agents:
    shogun:
      type: codex
    orchestrator:
      type: codex
    custom_role1:
      type: codex
    custom_role2:
      type: codex
    custom_role3:
      type: codex'

    load_registry_with "$settings"

    [ "$(agent_registry_pane_for_agent shogun 1)" = "shogun:main.1" ]
    [ "$(agent_registry_pane_for_agent telegram 1)" = "telegram:main.1" ]
    [ "$(agent_registry_multiagent_pane_for_agent orchestrator 1)" = "multiagent:ops.0" ]
    [ "$(agent_registry_multiagent_pane_for_agent custom_role1 1)" = "multiagent:agents.2" ]
    [ "$(agent_registry_multiagent_pane_for_agent custom_role3 1)" = "multiagent:agents.4" ]
}

@test "watcher_supervisor: --print-watchers uses dynamic settings and pane base" {
    local settings="$TEST_TMP/settings.yaml"
    write_settings "$settings" 'cli:
  agents:
    shogun:
      type: codex
    orchestrator:
      type: codex
    custom_role1:
      type: codex
    custom_role2:
      type: codex
    custom_role3:
      type: codex'

    run env AGENT_REGISTRY_SETTINGS="$settings" SHOGUN_PANE_BASE=1 \
        bash "$PROJECT_ROOT/scripts/watcher_supervisor.sh" --print-watchers

    [ "$status" -eq 0 ]
    [[ "$output" == *$'shogun\tshogun:main.1\tlogs/inbox_watcher_shogun.log'* ]]
    [[ "$output" == *$'orchestrator\tmultiagent:ops.0\tlogs/inbox_watcher_orchestrator.log'* ]]
    [[ "$output" == *$'custom_role1\tmultiagent:agents.2\tlogs/inbox_watcher_custom_role1.log'* ]]
    [[ "$output" == *$'custom_role2\tmultiagent:agents.3\tlogs/inbox_watcher_custom_role2.log'* ]]
    [[ "$output" == *$'custom_role3\tmultiagent:agents.4\tlogs/inbox_watcher_custom_role3.log'* ]]
}
