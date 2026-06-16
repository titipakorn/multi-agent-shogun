# Sub-Project A: Shogun V2 Topology Design

**Date:** 2026-06-16
**Sub-project:** A of 4 in the Specialist Agent Team Revamp
**Status:** Approved (pending spec self-review)
**Depends on:** None
**Enables:** Sub-D (config schema), Sub-B (orchestrator), Sub-C (specialists)

## Goal

Replace the existing 1-karo + 7-ashigaru + 1-gunshi pane topology with a 1-orchestrator + 7-specialist topology inspired by [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim). Keep multi-agent-shogun's YAML-based inbox communication and tmux pane model. Each agent (shogun, orchestrator, and the 7 specialists) gets its own tmux pane.

## Architecture Overview

9 panes across 3 sessions/windows:

| Session | Window | Panes | Role |
|---------|--------|-------|------|
| `shogun` | (main) | `shogun` | Top commander (Lord-facing) |
| `multiagent` | `ops` | `orchestrator`, `fixer`, `designer`, `observer` | Execution lane |
| `multiagent` | `research` | `explorer`, `librarian`, `oracle`, `council` | Analysis lane |

### Rationale for grouping

- **ops** = write-capable or execution-adjacent lanes (orchestrator delegates work; fixer/designer/observer do or inspect work product)
- **research** = read-only or reasoning-heavy lanes (explorer searches, librarian researches, oracle reviews, council deliberates)
- **shogun** stays separate so the Lord-facing interface is never crowded

### Pane positions

- Window `ops` (left-to-right): orchestrator → fixer → designer → observer
- Window `research` (left-to-right): explorer → librarian → oracle → council

### @agent_id values

`shogun`, `orchestrator`, `explorer`, `librarian`, `oracle`, `designer`, `fixer`, `observer`, `council`

### File naming convention

- `queue/inbox/{role}.yaml` (inbox)
- `queue/tasks/{role}.yaml` (assigned work)
- `queue/reports/{role}_report.yaml` (completion reports)

## Components & Startup Script

### Phase 1 — Session creation

```bash
# Existing: shogun session (untouched)
tmux new-session -d -s shogun -n main

# New: multiagent session with two windows
tmux new-session -d -s multiagent -n ops
tmux new-window -t multiagent -n research
```

### Phase 2 — Window "ops" panes (4 panes)

```bash
# Start with orchestrator at 0.0
# Add fixer, designer, observer via split-window
tmux send-keys -t multiagent:ops.0 "claude --model opus"   # orchestrator
# split, send-keys, repeat for fixer/designer/observer with their models
```

### Phase 3 — Window "research" panes (4 panes)

```bash
# Start with explorer at research.0
tmux send-keys -t multiagent:research.0 "claude --model haiku"  # explorer
# split, send-keys, repeat for librarian/oracle/council
```

### Phase 4 — @agent_id assignment

```bash
# For each pane, set the @agent_id option
tmux set-option -p -t multiagent:ops.0 @agent_id "orchestrator"
tmux set-option -p -t multiagent:ops.1 @agent_id "fixer"
tmux set-option -p -t multiagent:ops.2 @agent_id "designer"
tmux set-option -p -t multiagent:ops.3 @agent_id "observer"
tmux set-option -p -t multiagent:research.0 @agent_id "explorer"
tmux set-option -p -t multiagent:research.1 @agent_id "librarian"
tmux set-option -p -t multiagent:research.2 @agent_id "oracle"
tmux set-option -p -t multiagent:research.3 @agent_id "council"
tmux set-option -p -t shogun:main.0 @agent_id "shogun"
```

### Phase 5 — Pane styling (colors + titles)

| Pane | Background color | Title |
|------|------------------|-------|
| shogun | Solarized Dark (#002b36) | `shogun` |
| orchestrator | Red (#501515, existing karo color) | `orchestrator` |
| fixer | Green (#1e3a1e) | `fixer` |
| designer | Purple (#3a1e3a) | `designer` |
| observer | Cyan (#1e3a3a) | `observer` |
| explorer | Yellow (#454510) | `explorer` |
| librarian | Orange (#503515) | `librarian` |
| oracle | Gold (#454510, existing gunshi color) | `oracle` |
| council | Silver (#353535) | `council` |

### Phase 6 — inbox_watcher launch

One watcher per pane (9 total). Each watcher uses `{role}` as agent_id and the pane target as second arg.

### Removed from current script

- All `ashigaru{N}` references
- `karo` references (replaced by orchestrator)
- `gunshi` references (replaced by oracle/council)
- Old 1-karo + 7-ashigaru + 1-gunshi pane splitting logic

## CLI Startup & Model Routing

Each specialist pane launches the same CLI binary (default: `claude`), but with different model flags.

```bash
tmux send-keys -t multiagent:ops.0 "claude --model opus"        # orchestrator
tmux send-keys -t multiagent:ops.1 "claude --model sonnet"      # fixer
tmux send-keys -t multiagent:ops.2 "claude --model sonnet"      # designer
tmux send-keys -t multiagent:ops.3 "claude --model sonnet"      # observer
tmux send-keys -t multiagent:research.0 "claude --model haiku"   # explorer
tmux send-keys -t multiagent:research.1 "claude --model haiku"   # librarian
tmux send-keys -t multiagent:research.2 "claude --model opus"    # oracle
tmux send-keys -t multiagent:research.3 "claude --model opus"    # council
```

### Model defaults (configurable in settings.yaml)

| Role | Default Model | Rationale |
|------|---------------|-----------|
| orchestrator | opus | Strategic delegation decisions |
| explorer | haiku | Read-only grep/glob, cheapest |
| librarian | sonnet | Web research needs comprehension |
| oracle | opus | Architecture & review quality |
| designer | sonnet | UI/UX iteration speed |
| fixer | sonnet | Fast implementation |
| observer | sonnet | Visual analysis needs comprehension |
| council | opus | Multi-model consensus is expensive |

### CLI startup helper function

```bash
start_specialist_pane() {
    local session=$1 window=$2 pane_idx=$3 role=$4 model=$5
    local target="${session}:${window}.${pane_idx}"

    # Split pane if not pane 0
    if [ "$pane_idx" -gt 0 ]; then
        tmux split-window -h -t "${session}:${window}"
    fi

    # Set agent_id and styling
    tmux set-option -p -t "$target" @agent_id "$role"
    tmux select-pane -t "$target" -T "$role"
    tmux select-pane -t "$target" -P "bg=${ROLE_COLORS[$role]}"

    # Launch CLI
    tmux send-keys -t "$target" "claude --model $model" Enter
}
```

### Multi-CLI support

- `settings.yaml` → `cli.default: claude` (or codex/copilot/kimi/opencode/antigravity)
- Each pane reads `cli.default` and uses that binary
- Startup command template adapts per CLI (e.g., codex uses `codex --model X`, opencode uses `opencode run --model X`)
- Existing `cli_adapter.sh` and `switch_cli.sh` scripts are reused

## Error Handling & Recovery

### Pane failures

- If a specialist pane crashes (CLI exits), the existing `inotifywait`/`fswatch` watcher detects inactivity and logs to `logs/agent_status/`
- Recovery: orchestrator detects missing pane via `tmux list-panes` check at startup; if a specialist pane is gone, it logs to dashboard 🚨 section
- For Claude CLI crashes: existing `/clear` escalation in inbox_watcher handles context-corruption recovery; this stays unchanged

### Window losses

- If `multiagent:research` window is killed, orchestrator detects via `tmux list-windows` on next wakeup
- Recovery: orchestrator triggers `bash shutsujin_departure.sh --restart-research` to recreate the window + 4 panes + 4 watchers
- Shogun can trigger full restart via dashboard 🚨 if needed

### Watcher failures

- Each pane has one inbox_watcher. If watcher dies, supervisor (`scripts/watcher_supervisor.sh`) restarts it within 30s
- This already exists in the current system; no new logic needed

### Pane misidentification (the 2026-02-13 incident)

All panes set `@agent_id` via `tmux set-option -p`. Self-identification step in CLAUDE.md already reads this. New validation in `session_start_hook.sh`: if `@agent_id` doesn't match expected role for that pane position, abort startup with clear error:

| Pane target | Required @agent_id |
|-------------|---------------------|
| `multiagent:ops.0` | `orchestrator` |
| `multiagent:ops.1` | `fixer` |
| `multiagent:ops.2` | `designer` |
| `multiagent:ops.3` | `observer` |
| `multiagent:research.0` | `explorer` |
| `multiagent:research.1` | `librarian` |
| `multiagent:research.2` | `oracle` |
| `multiagent:research.3` | `council` |
| `shogun:main.0` | `shogun` |

### Migration safety

- Shutdown script iterates panes and sends graceful shutdown
- New script: `scripts/shutsujin_departure_v2.sh` exists alongside v1 during transition
- `first_setup.sh` reads `config/settings.yaml` → `topology:` field. If `topology: v2` is set, it calls the v2 script. If unset or `topology: v1`, it calls the v1 script. This allows safe rollback by editing one config line.
- Default in fresh `first_setup.sh` runs: `topology: v1` (current behavior) until sub-project A is fully tested and verified, then flipped to `v2` as the default.

## Testing & Validation

### Unit tests (extend `tests/` directory)

- `test_pane_creation.sh` — verifies `shutsujin_departure.sh` creates exactly 9 panes with correct `@agent_id` values and pane titles
- `test_pane_ids.sh` — iterates panes and confirms each has expected role (regression test for 2026-02-13 incident)
- `test_window_layout.sh` — confirms 4 panes in `ops` window and 4 panes in `research` window in correct order
- `test_color_scheme.sh` — verifies each pane has the expected background color via `tmux display -p`

### Integration tests

- `test_watcher_lifecycle.sh` — starts/shuts down the 9 watchers; verifies each is watching the correct inbox file
- `test_smoke_dispatch.sh` — sends a test inbox message to each specialist, confirms wake-up nudge arrives
- `test_cross_window_delivery.sh` — orchestrator in `ops` window sends to council in `research` window; verifies message arrives

### E2E validation (manual, then automated)

- Lord → Shogun → Orchestrator → 3 parallel specialists → Orchestrator → Shogun → Lord
- Each step verified by reading the relevant YAML/report
- This becomes a regression test before merging

### Backwards compat verification

- Run v1 topology: confirm all existing scripts (inbox_write, slim_yaml, etc.) work
- Run v2 topology: confirm new scripts work
- Switch between v1 and v2 via `settings.yaml` flag with no manual fixup needed

### Migration dry-run

New script `scripts/migrate_to_v2.sh`:
1. Detects running v1 session
2. Backs up queue/, reports/, dashboard.md
3. Spawns v2 topology in parallel
4. Re-routes inbox messages from old agents to new roles (karo → orchestrator, ashigaru{N} → mapped specialist, gunshi → oracle)
5. Verifies no message loss before tearing down v1

## Out of Scope (handled by later sub-projects)

- Sub-D: Detailed config schema for specialist permissions, skills, MCP assignments
- Sub-B: Orchestrator agent prompt with lane rules and dispatch decision flow
- Sub-C: The 7 specialist prompts (explorer, librarian, oracle, designer, fixer, observer, council)

## Open Questions for Later Phases

1. Which specialist gets the slot previously held by gunshi (`multiagent:research.3`)? Currently: council. Confirm in sub-C.
2. How are specialist permissions (read-only vs read-write) declared? In settings.yaml (sub-D) or in each specialist's instructions file (sub-C)?
3. Does the existing 24-min freeze lesson (foreground sleep ban in karo instructions) transfer to orchestrator as-is, or does orchestrator need different rules?
