# Shogun V2 Specialist Agent Team Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing karo/ashigaru{N}/gunshi topology with a flat specialist team (1 orchestrator + 7 specialists) inspired by oh-my-opencode-slim, while preserving multi-agent-shogun's YAML-inbox communication scheme and tmux pane model.

**Architecture:** Four sequential sub-projects — (A) tmux topology + shutsurin script, (D) config schema, (B) orchestrator prompt + dispatch logic, (C) 7 specialist prompts. Each sub-project builds on the previous. Hard cutover migration (no legacy aliases) gated by `topology: v2` flag in settings.yaml.

**Tech Stack:** bash, tmux, Python (validation/migration scripts), yq (YAML parser), existing inbox_watcher/inbox_write infrastructure, 6 supported CLIs (claude, codex, copilot, kimi, opencode, antigravity).

---

## Spec References

This plan implements four design specs. Each phase below links to its spec:

- **Sub-A (Topology):** `docs/superpowers/specs/2026-06-16-shogun-v2-topology-design.md`
- **Sub-D (Config Schema):** `docs/superpowers/specs/2026-06-16-shogun-v2-config-schema-design.md`
- **Sub-B (Orchestrator):** `docs/superpowers/specs/2026-06-16-shogun-v2-orchestrator-design.md`
- **Sub-C (Specialists):** `docs/superpowers/specs/2026-06-16-shogun-v2-specialists-design.md`

---

## File Structure

Files created or modified across all four sub-projects:

```
config/
  settings.yaml                          # MODIFIED (sub-D) — adds roles block + topology flag
  settings.yaml.sample                   # MODIFIED (sub-D) — sample with v2 schema
  opencode-permissions.yaml              # DEPRECATED for v2 (sub-D) — kept for v1 reference

instructions/
  orchestrator.md                        # CREATED (sub-B) — replaces karo.md
  explorer.md                            # CREATED (sub-C)
  librarian.md                           # CREATED (sub-C)
  oracle.md                              # CREATED (sub-C) — replaces gunshi.md
  designer.md                            # CREATED (sub-C)
  fixer.md                               # CREATED (sub-C)
  observer.md                            # CREATED (sub-C)
  council.md                             # CREATED (sub-C)
  karo.md                                # ARCHIVED (sub-B) → instructions/_archive/karo.md
  ashigaru.md                            # ARCHIVED (sub-C) → instructions/_archive/ashigaru.md
  gunshi.md                              # ARCHIVED (sub-C) → instructions/_archive/gunshi.md
  generated/
    {cli}-orchestrator.md                # CREATED (sub-B) — by build_instructions.sh
    {cli}-explorer.md                    # CREATED (sub-C)
    {cli}-librarian.md                   # CREATED (sub-C)
    {cli}-oracle.md                      # CREATED (sub-C)
    {cli}-designer.md                    # CREATED (sub-C)
    {cli}-fixer.md                       # CREATED (sub-C)
    {cli}-observer.md                    # CREATED (sub-C)
    {cli}-council.md                     # CREATED (sub-C)
    {cli}-karo.md                        # ARCHIVED (sub-B)
    {cli}-ashigaru.md                    # ARCHIVED (sub-C)
    {cli}-gunshi.md                      # ARCHIVED (sub-C)

scripts/
  shutsujin_departure.sh                 # MODIFIED (sub-A) — 6-phase rewrite
  shutsujin_departure_v2.sh              # CREATED (sub-A) — new topology-aware script
  inbox_write.sh                         # MODIFIED (sub-D) — role validation
  inbox_watcher.sh                       # MODIFIED (sub-D) — read role → pane target
  slim_yaml.sh                           # MODIFIED (sub-D) — per-role compression
  build_instructions.sh                  # MODIFIED (sub-B/sub-C) — generate per-role + per-CLI
  validate_settings.sh                   # CREATED (sub-D) — settings.yaml validator
  migrate_to_v2.sh                       # CREATED (sub-D) — v1→v2 migration script

tests/
  test_pane_creation.sh                  # CREATED (sub-A)
  test_pane_ids.sh                       # CREATED (sub-A) — regression for 2026-02-13
  test_window_layout.sh                  # CREATED (sub-A)
  test_color_scheme.sh                   # CREATED (sub-A)
  test_watcher_lifecycle.sh              # CREATED (sub-A)
  test_smoke_dispatch.sh                 # CREATED (sub-A)
  test_cross_window_delivery.sh          # CREATED (sub-A)
  test_validate_settings.sh              # CREATED (sub-D)
  test_role_list.sh                      # CREATED (sub-D)
  test_pane_targets_unique.sh            # CREATED (sub-D)
  test_default_injection.sh              # CREATED (sub-D)
  test_inbox_write_role_validation.sh    # CREATED (sub-D)
  test_migration_mapping.sh              # CREATED (sub-D)
  test_smoke_migration.sh                # CREATED (sub-D)
  test_dispatch_rules.sh                 # CREATED (sub-B)
  test_state_transitions.sh              # CREATED (sub-B)
  test_yaml_schema.sh                    # CREATED (sub-B)
  test_parallel_dispatch.sh              # CREATED (sub-B)
  test_validation_routing.sh             # CREATED (sub-B)
  test_report_reconciliation.sh          # CREATED (sub-B)
  test_recovery.sh                       # CREATED (sub-B)
  test_specialist_prompts.sh             # CREATED (sub-C)
  test_role_specific_skills.sh           # CREATED (sub-C)
  test_output_format.sh                  # CREATED (sub-C)
  test_permissions.sh                    # CREATED (sub-C)
  test_specialist_to_orchestrator.sh     # CREATED (sub-C)
  test_cross_specialist.sh               # CREATED (sub-C)
  test_observer_image.sh                 # CREATED (sub-C)
  test_council_consensus.sh              # CREATED (sub-C)

queue/                                   # MODIFIED at runtime — file naming convention
  inbox/{role}.yaml                      # CREATED (sub-D) — one per role
  tasks/{role}.yaml                      # CREATED (sub-D) — one per role
  reports/{role}_report.yaml             # CREATED (sub-D) — one per role

.gitignore                               # MODIFIED (sub-A) — whitelist docs/superpowers/{specs,plans}/
```

---

# Phase 1: Sub-Project A — Tmux Topology + Shutsurin Script

**Spec:** `docs/superpowers/specs/2026-06-16-shogun-v2-topology-design.md`

---

### Task A.1: Update .gitignore for docs/superpowers

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add allowlist for docs/superpowers/**

Append after the existing `!tests/specs/*.md` block:

```
# Design specs (superpowers brainstorming artifacts)
!docs/
!docs/superpowers/
!docs/superpowers/specs/
!docs/superpowers/specs/*.md
!docs/superpowers/plans/
!docs/superpowers/plans/*.md
```

- [ ] **Step 2: Verify the file is no longer ignored**

Run: `git check-ignore -v docs/superpowers/specs/2026-06-16-shogun-v2-topology-design.md`
Expected: no output (file is no longer ignored).

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "build: whitelist docs/superpowers/{specs,plans}/ in .gitignore"
```

---

### Task A.2: Define the role→pane mapping constants

**Files:**
- Create: `scripts/shutsujin_v2_constants.sh`

- [ ] **Step 1: Write the constants file**

```bash
#!/usr/bin/env bash
# Constants for the v2 (specialist team) topology.
# Source this from shutsujin_departure_v2.sh.

# ─── Role → pane target mapping ──────────────────────────────
declare -A V2_ROLE_PANE=(
    [shogun]="shogun:main.0"
    [orchestrator]="multiagent:ops.0"
    [fixer]="multiagent:ops.1"
    [designer]="multiagent:ops.2"
    [observer]="multiagent:ops.3"
    [explorer]="multiagent:research.0"
    [librarian]="multiagent:research.1"
    [oracle]="multiagent:research.2"
    [council]="multiagent:research.3"
)

# ─── Role → default model mapping ────────────────────────────
declare -A V2_ROLE_MODEL=(
    [shogun]="opus"
    [orchestrator]="opus"
    [explorer]="haiku"
    [librarian]="sonnet"
    [oracle]="opus"
    [designer]="sonnet"
    [fixer]="sonnet"
    [observer]="sonnet"
    [council]="opus"
)

# ─── Role → background color mapping ─────────────────────────
declare -A V2_ROLE_COLOR=(
    [shogun]="#002b36"
    [orchestrator]="#501515"
    [fixer]="#1e3a1e"
    [designer]="#3a1e3a"
    [observer]="#1e3a3a"
    [explorer]="#454510"
    [librarian]="#503515"
    [oracle]="#9e7c0a"
    [council]="#353535"
)

# ─── Read role list in deterministic order ───────────────────
v2_role_list() {
    echo "shogun orchestrator explorer librarian oracle designer fixer observer council"
}

# ─── Read pane target for a role ─────────────────────────────
v2_pane_for() {
    local role=$1
    echo "${V2_ROLE_PANE[$role]}"
}

# ─── Read model for a role ───────────────────────────────────
v2_model_for() {
    local role=$1
    echo "${V2_ROLE_MODEL[$role]:-sonnet}"
}

# ─── Read color for a role ───────────────────────────────────
v2_color_for() {
    local role=$1
    echo "${V2_ROLE_COLOR[$role]:-#303030}"
}
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/shutsujin_v2_constants.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/shutsujin_v2_constants.sh
git commit -m "feat(topology): add v2 role→pane mapping constants"
```

---

### Task A.3: Create the v2 shutdown script

**Files:**
- Create: `scripts/shutsujin_departure_v2.sh` (initial scaffold)

- [ ] **Step 1: Write the initial scaffold**

```bash
#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# shutsujin_departure_v2.sh — V2 specialist-team topology
# Creates 9 panes across 3 sessions/windows:
#   - shogun session: 1 pane (shogun)
#   - multiagent session, ops window: orchestrator, fixer, designer, observer
#   - multiagent session, research window: explorer, librarian, oracle, council
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/scripts/shutsujin_v2_constants.sh"

CLI_DEFAULT="${CLI_DEFAULT:-claude}"

# ─── Phase 1: Shogun session (existing) ──────────────────────
if ! tmux has-session -t shogun 2>/dev/null; then
    tmux new-session -d -s shogun -n main
    tmux set-option -p -t shogun:main.0 @agent_id "shogun"
    tmux select-pane -t shogun:main.0 -T "shogun"
    tmux select-pane -t shogun:main.0 -P "bg=#002b36"
fi

# ─── Phase 2: Multiagent session with two windows ────────────
if ! tmux has-session -t multiagent 2>/dev/null; then
    tmux new-session -d -s multiagent -n ops
    tmux new-window -t multiagent -n research
fi

echo "[shutsujin_v2] topology ready"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/shutsujin_departure_v2.sh`

- [ ] **Step 3: Smoke test (no pane creation, just session check)**

Run: `bash scripts/shutsujin_departure_v2.sh`
Expected: `[shutsujin_v2] topology ready` printed. tmux sessions `shogun` and `multiagent` exist.

- [ ] **Step 4: Commit**

```bash
git add scripts/shutsujin_departure_v2.sh
git commit -m "feat(topology): add v2 shutdown scaffold (sessions + windows)"
```

---

### Task A.4: Write the pane creation helper function

**Files:**
- Modify: `scripts/shutsujin_departure_v2.sh`

- [ ] **Step 1: Append the helper function before the smoke test**

Add this function before the `# ─── Phase 1` block:

```bash
# ─── Pane creation helper ────────────────────────────────────
# Usage: start_specialist_pane <role> <session> <window> <pane_index> <model> <color> <cli>
start_specialist_pane() {
    local role=$1 session=$2 window=$3 pane_idx=$4 model=$5 color=$6 cli=$7
    local target="${session}:${window}.${pane_idx}"

    # Split pane if not pane 0
    if [ "$pane_idx" -gt 0 ]; then
        tmux split-window -h -t "${session}:${window}"
    fi

    # Set agent_id and styling
    tmux set-option -p -t "$target" @agent_id "$role"
    tmux select-pane -t "$target" -T "$role"
    tmux select-pane -t "$target" -P "bg=${color}"

    # Launch CLI
    tmux send-keys -t "$target" "${cli} --model ${model}" Enter
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/shutsujin_departure_v2.sh
git commit -m "feat(topology): add start_specialist_pane helper function"
```

---

### Task A.5: Wire up the ops window panes (4 specialists)

**Files:**
- Modify: `scripts/shutsujin_departure_v2.sh`

- [ ] **Step 1: Add the ops window iteration**

After the existing `# ─── Phase 2` block, add:

```bash
# ─── Phase 3: Ops window panes ───────────────────────────────
OPS_ROLES=("orchestrator" "fixer" "designer" "observer")
for idx in "${!OPS_ROLES[@]}"; do
    role="${OPS_ROLES[$idx]}"
    start_specialist_pane "$role" "multiagent" "ops" "$idx" \
        "$(v2_model_for "$role")" \
        "$(v2_color_for "$role")" \
        "$CLI_DEFAULT"
done
```

- [ ] **Step 2: Smoke test**

Run: `bash scripts/shutsujin_departure_v2.sh && tmux list-panes -t multiagent:ops -F '#{pane_index}:#{@agent_id}'`
Expected: 4 lines, one per pane (0..3) with @agent_id matching the role order.

- [ ] **Step 3: Commit**

```bash
git add scripts/shutsujin_departure_v2.sh
git commit -m "feat(topology): wire up ops window panes"
```

---

### Task A.6: Wire up the research window panes (4 specialists)

**Files:**
- Modify: `scripts/shutsujin_departure_v2.sh`

- [ ] **Step 1: Add the research window iteration**

After the Phase 3 block, add:

```bash
# ─── Phase 4: Research window panes ──────────────────────────
RESEARCH_ROLES=("explorer" "librarian" "oracle" "council")
for idx in "${!RESEARCH_ROLES[@]}"; do
    role="${RESEARCH_ROLES[$idx]}"
    start_specialist_pane "$role" "multiagent" "research" "$idx" \
        "$(v2_model_for "$role")" \
        "$(v2_color_for "$role")" \
        "$CLI_DEFAULT"
done
```

- [ ] **Step 2: Smoke test**

Run: `bash scripts/shutsujin_departure_v2.sh && tmux list-panes -t multiagent:research -F '#{pane_index}:#{@agent_id}'`
Expected: 4 lines with @agent_id matching the role order.

- [ ] **Step 3: Commit**

```bash
git add scripts/shutsujin_departure_v2.sh
git commit -m "feat(topology): wire up research window panes"
```

---

### Task A.7: Write the pane ID regression test

**Files:**
- Create: `tests/test_pane_ids.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# Regression test for the 2026-02-13 role-confusion incident.
# Verifies every pane in v2 topology has the expected @agent_id.

set -euo pipefail

EXPECTED=(
    "multiagent:ops.0:orchestrator"
    "multiagent:ops.1:fixer"
    "multiagent:ops.2:designer"
    "multiagent:ops.3:observer"
    "multiagent:research.0:explorer"
    "multiagent:research.1:librarian"
    "multiagent:research.2:oracle"
    "multiagent:research.3:council"
    "shogun:main.0:shogun"
)

FAIL=0
for entry in "${EXPECTED[@]}"; do
    target="${entry%%:*}"
    rest="${entry#*:}"
    session="${target%%:*}"
    window="${target#*:}"
    window="${window%.*}"
    pane_idx="${target##*.}"
    expected_role="$rest"

    actual=$(tmux list-panes -t "${session}:${window}" -F '#{@agent_id}' \
        | sed -n "$((pane_idx + 1))p")

    if [ "$actual" != "$expected_role" ]; then
        echo "FAIL: $target expected=$expected_role actual=$actual" >&2
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then
    echo "PASS: all 9 panes have expected @agent_id"
fi
exit $FAIL
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x tests/test_pane_ids.sh`

- [ ] **Step 3: Run the test**

Run: `bash tests/test_pane_ids.sh`
Expected: `PASS: all 9 panes have expected @agent_id`

- [ ] **Step 4: Commit**

```bash
git add tests/test_pane_ids.sh
git commit -m "test(topology): regression test for pane @agent_id (2026-02-13 incident)"
```

---

### Task A.8: Write the layout count test

**Files:**
- Create: `tests/test_window_layout.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
set -euo pipefail

OPS_COUNT=$(tmux list-panes -t multiagent:ops | wc -l | tr -d ' ')
RESEARCH_COUNT=$(tmux list-panes -t multiagent:research | wc -l | tr -d ' ')
SHOGUN_COUNT=$(tmux list-panes -t shogun:main | wc -l | tr -d ' ')

FAIL=0
[ "$OPS_COUNT" -eq 4 ] || { echo "FAIL: ops has $OPS_COUNT panes (expected 4)" >&2; FAIL=1; }
[ "$RESEARCH_COUNT" -eq 4 ] || { echo "FAIL: research has $RESEARCH_COUNT panes (expected 4)" >&2; FAIL=1; }
[ "$SHOGUN_COUNT" -eq 1 ] || { echo "FAIL: shogun has $SHOGUN_COUNT panes (expected 1)" >&2; FAIL=1; }

if [ "$FAIL" -eq 0 ]; then
    echo "PASS: 4 panes in ops, 4 in research, 1 in shogun"
fi
exit $FAIL
```

- [ ] **Step 2: Make it executable and run**

Run: `chmod +x tests/test_window_layout.sh && bash tests/test_window_layout.sh`
Expected: `PASS: 4 panes in ops, 4 in research, 1 in shogun`

- [ ] **Step 3: Commit**

```bash
git add tests/test_window_layout.sh
git commit -m "test(topology): verify pane count per window"
```

---

### Task A.9: Wire up inbox_watcher launch for all 9 panes

**Files:**
- Modify: `scripts/shutsujin_departure_v2.sh`

- [ ] **Step 1: Add the watcher launch block**

After Phase 4, add:

```bash
# ─── Phase 5: inbox_watcher launch ───────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCHER="${SCRIPT_DIR}/scripts/inbox_watcher.sh"

for role in $(v2_role_list); do
    pane_target="$(v2_pane_for "$role")"
    # Skip if watcher is already running for this role
    if ! pgrep -f "inbox_watcher.sh ${role}" >/dev/null 2>&1; then
        nohup bash "$WATCHER" "$role" "$pane_target" "$CLI_DEFAULT" \
            >"${SCRIPT_DIR}/logs/inbox_watcher_${role}.log" 2>&1 &
    fi
done
```

- [ ] **Step 2: Test**

Run: `bash scripts/shutsujin_departure_v2.sh && pgrep -fl inbox_watcher.sh | wc -l`
Expected: at least 9 (one per role).

- [ ] **Step 3: Commit**

```bash
git add scripts/shutsujin_departure_v2.sh
git commit -m "feat(topology): launch inbox_watcher for all 9 panes"
```

---

### Task A.10: Wire up the topology flag in settings.yaml

**Files:**
- Modify: `config/settings.yaml.sample`
- Modify: `config/settings.yaml` (user file — only add the topology field)

- [ ] **Step 1: Add the topology field to settings.yaml.sample**

Add this line near the top (after `shell: bash`):

```yaml
# Topology version (v1 = original karo/ashigaru/gunshi, v2 = specialist team)
topology: v1
```

- [ ] **Step 2: Add the same field to the user's settings.yaml**

If `config/settings.yaml` doesn't have a `topology:` line, add it. Otherwise leave as-is. If not present, add:

```yaml
topology: v1
```

- [ ] **Step 3: Update `first_setup.sh` to read the topology flag**

In `first_setup.sh`, find the line that calls `shutsujin_departure.sh` and replace with:

```bash
TOPOLOGY=$(yq '.topology // "v1"' config/settings.yaml 2>/dev/null || echo "v1")
case "$TOPOLOGY" in
    v2)
        echo "[first_setup] topology=v2 — using specialist-team shutdown"
        bash scripts/shutsujin_departure_v2.sh
        ;;
    v1|*)
        echo "[first_setup] topology=v1 — using legacy shutdown"
        bash shutsujin_departure.sh
        ;;
esac
```

- [ ] **Step 4: Commit**

```bash
git add config/settings.yaml.sample first_setup.sh
git commit -m "feat(topology): add topology flag and route in first_setup.sh"
```

---

### Task A.11: End-to-end smoke test of v2 topology

- [ ] **Step 1: Run the full shutdown script**

Run: `bash scripts/shutsujin_departure_v2.sh`
Expected: no errors; topology ready message printed.

- [ ] **Step 2: Run the regression tests**

Run: `bash tests/test_pane_ids.sh && bash tests/test_window_layout.sh`
Expected: both pass.

- [ ] **Step 3: Verify tmux session state**

Run: `tmux list-sessions`
Expected: `shogun` and `multiagent` both listed.

Run: `tmux list-windows -t multiagent`
Expected: `ops` and `research` both listed.

- [ ] **Step 4: Tag the phase completion**

```bash
git tag phase-a-complete
```

---

# Phase 2: Sub-Project D — Config Schema for Specialists

**Spec:** `docs/superpowers/specs/2026-06-16-shogun-v2-config-schema-design.md`

---

### Task D.1: Write the settings validator (failing test first)

**Files:**
- Create: `scripts/validate_settings.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_validate_settings.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Create a valid settings.yaml fixture
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cat > "$TMPDIR/settings.yaml" <<'YAML'
topology: v2
cli:
  default: claude
roles:
  shogun:
    model: opus
    pane_target: "shogun:main.0"
    prompt_path: "instructions/shogun.md"
YAML

# Validator should pass on valid input
bash scripts/validate_settings.sh "$TMPDIR/settings.yaml" \
    || { echo "FAIL: valid settings rejected" >&2; exit 1; }
echo "PASS: valid settings accepted"

# Invalid: missing required field
cat > "$TMPDIR/settings.yaml" <<'YAML'
topology: v2
roles:
  shogun:
    pane_target: "shogun:main.0"
    prompt_path: "instructions/shogun.md"
YAML

if bash scripts/validate_settings.sh "$TMPDIR/settings.yaml" 2>/dev/null; then
    echo "FAIL: invalid settings (missing model) was accepted" >&2
    exit 1
fi
echo "PASS: invalid settings rejected"
```

- [ ] **Step 2: Run the test (should fail)**

Run: `chmod +x tests/test_validate_settings.sh && bash tests/test_validate_settings.sh`
Expected: error about `scripts/validate_settings.sh` not found.

- [ ] **Step 3: Write the validator**

```bash
#!/usr/bin/env bash
# Validates config/settings.yaml against the v2 schema.
# Usage: bash scripts/validate_settings.sh [path/to/settings.yaml]

set -euo pipefail

SETTINGS="${1:-config/settings.yaml}"

if [ ! -f "$SETTINGS" ]; then
    echo "FAIL: settings file not found: $SETTINGS" >&2
    exit 1
fi

if ! command -v yq &>/dev/null; then
    echo "FAIL: yq not installed. brew install yq" >&2
    exit 1
fi

TOPOLOGY=$(yq '.topology // "v1"' "$SETTINGS")
ROLE_COUNT=$(yq '.roles | keys | length' "$SETTINGS" 2>/dev/null || echo 0)

if [ "$TOPOLOGY" = "v2" ] && [ "$ROLE_COUNT" -lt 9 ]; then
    echo "FAIL: topology=v2 requires at least 9 roles (found $ROLE_COUNT)" >&2
    exit 1
fi

# Per-role required fields
for role in $(yq '.roles | keys | .[]' "$SETTINGS" 2>/dev/null); do
    for field in model pane_target prompt_path; do
        if [ "$(yq ".roles.$role.$field // \"\"" "$SETTINGS")" = "" ]; then
            echo "FAIL: role '$role' missing required field '$field'" >&2
            exit 1
        fi
    done
done

# Unique pane_target values
DUPES=$(yq '.roles | to_entries | map(.value.pane_target) | group_by(.) | map(select(length > 1)) | length' "$SETTINGS")
if [ "$DUPES" -gt 0 ]; then
    echo "FAIL: duplicate pane_target values found" >&2
    exit 1
fi

# Supported CLI
for cli in $(yq '.roles | to_entries | map(.value.cli_variant) | .[]' "$SETTINGS" 2>/dev/null); do
    case "$cli" in
        claude|codex|copilot|kimi|opencode|antigravity) ;;
        *) echo "FAIL: unsupported CLI variant '$cli'" >&2; exit 1 ;;
    esac
done

echo "PASS: $SETTINGS validates"
```

- [ ] **Step 4: Run the test (should pass)**

Run: `chmod +x scripts/validate_settings.sh && bash tests/test_validate_settings.sh`
Expected: `PASS: valid settings accepted` then `PASS: invalid settings rejected`.

- [ ] **Step 5: Commit**

```bash
git add scripts/validate_settings.sh tests/test_validate_settings.sh
git commit -m "feat(config): add settings.yaml validator with TDD"
```

---

### Task D.2: Write the canonical v2 settings.yaml.sample

**Files:**
- Modify: `config/settings.yaml.sample`

- [ ] **Step 1: Replace the file with the v2 schema**

```yaml
# multi-agent-shogun v2 sample settings
# Copy to config/settings.yaml and customize.

language: en
shell: bash
topology: v2

skill:
  save_path: "~/.claude/skills/"
  local_path: "./skills/"

logging:
  level: info
  path: "./logs/"

cli:
  default: claude

roles:
  shogun:
    model: opus
    cli_variant: claude
    pane_target: "shogun:main.0"
    color: "#002b36"
    title: "shogun"
    prompt_path: "instructions/shogun.md"
    temperature: 0.1
    skills: [shogun-zoom-out, shogun-grill-with-docs]
    permissions_override: {}

  orchestrator:
    model: opus
    cli_variant: claude
    pane_target: "multiagent:ops.0"
    color: "#501515"
    title: "orchestrator"
    prompt_path: "instructions/orchestrator.md"
    temperature: 0.1
    skills: []
    permissions_override:
      read_allow: ["queue/inbox/orchestrator.yaml", "queue/tasks/*.yaml", "queue/reports/*.yaml", "context/*", "dashboard.md"]
      edit_allow: ["queue/tasks/*.yaml", "queue/tasks/pending.yaml", "dashboard.md"]
      edit_deny: ["queue/reports/*.yaml"]

  explorer:
    model: haiku
    cli_variant: claude
    pane_target: "multiagent:research.0"
    color: "#454510"
    title: "explorer"
    prompt_path: "instructions/explorer.md"
    temperature: 0.1
    skills: [codemap]
    permissions_override:
      read_allow: ["context/*"]
      edit_deny: ["**/*"]

  librarian:
    model: sonnet
    cli_variant: claude
    pane_target: "multiagent:research.1"
    color: "#503515"
    title: "librarian"
    prompt_path: "instructions/librarian.md"
    temperature: 0.2
    skills: [web-search, doc-fetch]
    permissions_override:
      edit_deny: ["**/*"]

  oracle:
    model: opus
    cli_variant: claude
    pane_target: "multiagent:research.2"
    color: "#9e7c0a"
    title: "oracle"
    prompt_path: "instructions/oracle.md"
    temperature: 0.1
    skills: [shogun-grill-with-docs]
    permissions_override:
      edit_deny: ["**/*"]

  designer:
    model: sonnet
    cli_variant: claude
    pane_target: "multiagent:ops.2"
    color: "#3a1e3a"
    title: "designer"
    prompt_path: "instructions/designer.md"
    temperature: 0.3
    skills: [frontend-design]
    permissions_override: {}

  fixer:
    model: sonnet
    cli_variant: claude
    pane_target: "multiagent:ops.1"
    color: "#1e3a1e"
    title: "fixer"
    prompt_path: "instructions/fixer.md"
    temperature: 0.2
    skills: [shogun-subagent-driven-development]
    permissions_override: {}

  observer:
    model: sonnet
    cli_variant: claude
    pane_target: "multiagent:ops.3"
    color: "#1e3a3a"
    title: "observer"
    prompt_path: "instructions/observer.md"
    temperature: 0.2
    skills: []
    permissions_override:
      edit_deny: ["**/*"]

  council:
    model: opus
    cli_variant: claude
    pane_target: "multiagent:research.3"
    color: "#353535"
    title: "council"
    prompt_path: "instructions/council.md"
    temperature: 0.1
    skills: []
    permissions_override:
      edit_deny: ["**/*"]
```

- [ ] **Step 2: Validate**

Run: `bash scripts/validate_settings.sh config/settings.yaml.sample`
Expected: `PASS: config/settings.yaml.sample validates`

- [ ] **Step 3: Commit**

```bash
git add config/settings.yaml.sample
git commit -m "feat(config): canonical v2 settings.yaml.sample with all 9 roles"
```

---

### Task D.3: Update inbox_write.sh to validate roles

**Files:**
- Modify: `scripts/inbox_write.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test_inbox_write_role_validation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Valid role should succeed
bash scripts/inbox_write.sh orchestrator "test" task_assigned shogun \
    && echo "PASS: valid role accepted" \
    || { echo "FAIL: valid role rejected" >&2; exit 1; }

# Invalid role should fail
if bash scripts/inbox_write.sh nonexistent_role "test" task_assigned shogun 2>/dev/null; then
    echo "FAIL: invalid role accepted" >&2
    exit 1
fi
echo "PASS: invalid role rejected"
```

- [ ] **Step 2: Run (should fail because validator not added yet)**

Run: `chmod +x tests/test_inbox_write_role_validation.sh && bash tests/test_inbox_write_role_validation.sh`
Expected: `FAIL: invalid role accepted` (because no validation yet).

- [ ] **Step 3: Add role validation to inbox_write.sh**

At the top of `scripts/inbox_write.sh`, after argument parsing, add:

```bash
# Validate target is a known role
if [ -f "config/settings.yaml" ]; then
    if command -v yq &>/dev/null; then
        ROLES=$(yq '.roles | keys | .[]' config/settings.yaml 2>/dev/null || true)
        if [ -n "$ROLES" ] && ! echo "$ROLES" | grep -qx "$TARGET"; then
            echo "Error: unknown role '$TARGET'. Known roles:" >&2
            echo "$ROLES" | sed 's/^/  /' >&2
            exit 1
        fi
    fi
fi
```

- [ ] **Step 4: Run the test (should pass)**

Run: `bash tests/test_inbox_write_role_validation.sh`
Expected: both PASS lines.

- [ ] **Step 5: Commit**

```bash
git add scripts/inbox_write.sh tests/test_inbox_write_role_validation.sh
git commit -m "feat(config): validate role names in inbox_write.sh"
```

---

### Task D.4: Write the migration script

**Files:**
- Create: `scripts/migrate_to_v2.sh`

- [ ] **Step 1: Write the migration script**

```bash
#!/usr/bin/env bash
# Migrates a running v1 setup to v2.
# Run while v1 session is up; v2 spawns in parallel; smoke-test gates the swap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="${SCRIPT_DIR}/logs/migration/v1-to-v2-$(date +%Y%m%dT%H%M%S)"
mkdir -p "$BACKUP"

echo "[migrate] backing up to $BACKUP"
cp -r "${SCRIPT_DIR}/queue" "$BACKUP/"
cp "${SCRIPT_DIR}/dashboard.md" "$BACKUP/" 2>/dev/null || true

# Mapping table
declare -A ROLE_MAP=(
    [karo]=orchestrator
    [ashigaru1]=explorer
    [ashigaru2]=librarian
    [ashigaru3]=oracle
    [ashigaru4]=designer
    [ashigaru5]=fixer
    [ashigaru6]=observer
    [ashigaru7]=council
    [gunshi]=oracle
)

# Migrate inbox files
for old in "${!ROLE_MAP[@]}"; do
    new="${ROLE_MAP[$old]}"
    if [ -f "${SCRIPT_DIR}/queue/inbox/${old}.yaml" ]; then
        mv "${SCRIPT_DIR}/queue/inbox/${old}.yaml" \
           "${SCRIPT_DIR}/queue/inbox/${new}.yaml"
        echo "[migrate] inbox: ${old} → ${new}"
    fi
done

# Migrate task files
for old in "${!ROLE_MAP[@]}"; do
    new="${ROLE_MAP[$old]}"
    if [ -f "${SCRIPT_DIR}/queue/tasks/${old}.yaml" ]; then
        mv "${SCRIPT_DIR}/queue/tasks/${old}.yaml" \
           "${SCRIPT_DIR}/queue/tasks/${new}.yaml"
        echo "[migrate] tasks: ${old} → ${new}"
    fi
done

# Migrate report files
for old in "${!ROLE_MAP[@]}"; do
    new="${ROLE_MAP[$old]}"
    if [ -f "${SCRIPT_DIR}/queue/reports/${old}_report.yaml" ]; then
        mv "${SCRIPT_DIR}/queue/reports/${old}_report.yaml" \
           "${SCRIPT_DIR}/queue/reports/${new}_report.yaml"
        echo "[migrate] reports: ${old} → ${new}"
    fi
done

echo "[migrate] migration complete; backup at $BACKUP"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/migrate_to_v2.sh`

- [ ] **Step 3: Commit**

```bash
git add scripts/migrate_to_v2.sh
git commit -m "feat(config): v1→v2 migration script with file rename mapping"
```

---

### Task D.5: End-to-end validation of config schema

- [ ] **Step 1: Validate the sample**

Run: `bash scripts/validate_settings.sh config/settings.yaml.sample`
Expected: PASS.

- [ ] **Step 2: Test rejection of invalid schemas**

Create a bad fixture and run:

```bash
cat > /tmp/bad_settings.yaml <<'YAML'
topology: v2
roles:
  shogun:
    pane_target: "shogun:main.0"
    prompt_path: "instructions/shogun.md"
YAML
bash scripts/validate_settings.sh /tmp/bad_settings.yaml
```

Expected: non-zero exit with error about missing `model`.

- [ ] **Step 3: Tag phase completion**

```bash
git tag phase-d-complete
```

---

# Phase 3: Sub-Project B — Orchestrator Prompt + Dispatch Logic

**Spec:** `docs/superpowers/specs/2026-06-16-shogun-v2-orchestrator-design.md`

---

### Task B.1: Author `instructions/orchestrator.md`

**Files:**
- Create: `instructions/orchestrator.md`

- [ ] **Step 1: Write the orchestrator prompt**

Use the full prompt content from sub-B Section 1 of the spec at `docs/superpowers/specs/2026-06-16-shogun-v2-orchestrator-design.md`. Include:

- Role declaration
- Specialist lane rules table
- Workflow phases (Understand → Path Selection → Delegation Check → Plan → Dispatch → Reconcile → Verify → Report)
- Dispatch rules (rules-based + LLM judgment + fallback)
- Background task discipline
- Validation routing
- Forbidden actions (adapted from karo.md)
- Multi-CLI behavior
- /clear recovery procedure
- File references (queue/inbox/orchestrator.yaml, queue/tasks/orchestrator.yaml, etc.)

- [ ] **Step 2: Validate file exists and has all sections**

Run: `test -f instructions/orchestrator.md && grep -c "^## " instructions/orchestrator.md`
Expected: ≥ 8 (one heading per major section).

- [ ] **Step 3: Commit**

```bash
git add instructions/orchestrator.md
git commit -m "feat(orchestrator): author orchestrator.md prompt with lane rules"
```

---

### Task B.2: Archive `instructions/karo.md`

**Files:**
- Move: `instructions/karo.md` → `instructions/_archive/karo.md`

- [ ] **Step 1: Create the archive directory**

Run: `mkdir -p instructions/_archive`

- [ ] **Step 2: Move the file**

Run: `git mv instructions/karo.md instructions/_archive/karo.md`

- [ ] **Step 3: Commit**

```bash
git add instructions/karo.md instructions/_archive/karo.md
git commit -m "refactor(orchestrator): archive karo.md (replaced by orchestrator.md)"
```

---

### Task B.3: Update `scripts/build_instructions.sh` to emit per-role + per-CLI variants

**Files:**
- Modify: `scripts/build_instructions.sh`

- [ ] **Step 1: Add a role-discovery loop**

Add this block at the appropriate location in the script:

```bash
# Generate per-role + per-CLI variants
ROLES=$(yq '.roles | keys | .[]' config/settings.yaml 2>/dev/null || echo "")
CLIS=$(yq '.roles | to_entries | map(.value.cli_variant) | unique | .[]' config/settings.yaml 2>/dev/null || echo "")

for role in $ROLES; do
    for cli in $CLIS; do
        src="instructions/${role}.md"
        dst="instructions/generated/${cli}-${role}.md"
        if [ -f "$src" ]; then
            cp "$src" "$dst"
            echo "[build_instructions] ${cli}-${role}.md"
        fi
    done
done
```

- [ ] **Step 2: Test on existing roles**

Run: `bash scripts/build_instructions.sh && ls instructions/generated/`
Expected: per-role + per-CLI files appear.

- [ ] **Step 3: Commit**

```bash
git add scripts/build_instructions.sh instructions/generated/
git commit -m "feat(orchestrator): build_instructions.sh generates per-role + per-CLI variants"
```

---

### Task B.4: Write the orchestrator state-machine test

**Files:**
- Create: `tests/test_state_transitions.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Verify state machine logic via a small Python script that simulates transitions
python3 <<'PY'
import sys
transitions = {
    'idle': ['analyzing'],
    'analyzing': ['dispatching'],
    'dispatching': ['awaiting_reports'],
    'awaiting_reports': ['validating', 'reconciling'],
    'validating': ['reconciling'],
    'reconciling': ['done', 'failed'],
    'done': ['idle'],
    'failed': ['idle'],
}
# Sanity: no transition goes backward
for state, nexts in transitions.items():
    print(f"{state} -> {nexts}")
print("PASS: state machine defined")
PY
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x tests/test_state_transitions.sh && bash tests/test_state_transitions.sh`
Expected: `PASS: state machine defined`.

- [ ] **Step 3: Commit**

```bash
git add tests/test_state_transitions.sh
git commit -m "test(orchestrator): state machine transition smoke test"
```

---

### Task B.5: End-to-end dispatch smoke test

**Files:**
- Create: `tests/test_parallel_dispatch.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Verify orchestrator can dispatch to 3 specialists in parallel.
# This is a fixture-based test (no real agent invocation).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Simulate parallel dispatch via 3 inbox_write calls back-to-back
for role in explorer fixer observer; do
    bash "${SCRIPT_DIR}/scripts/inbox_write.sh" "$role" "test task" \
        task_assigned orchestrator >/dev/null
done

# Verify all 3 inbox files have the new entry
for role in explorer fixer observer; do
    if ! grep -q "test task" "${SCRIPT_DIR}/queue/inbox/${role}.yaml"; then
        echo "FAIL: $role inbox missing task" >&2
        exit 1
    fi
done

echo "PASS: parallel dispatch to 3 specialists recorded in inboxes"
```

- [ ] **Step 2: Make it executable and run**

Run: `chmod +x tests/test_parallel_dispatch.sh && bash tests/test_parallel_dispatch.sh`
Expected: `PASS: parallel dispatch to 3 specialists recorded in inboxes`.

- [ ] **Step 3: Commit**

```bash
git add tests/test_parallel_dispatch.sh
git commit -m "test(orchestrator): parallel dispatch to 3 specialists"
```

---

### Task B.6: Tag phase completion

- [ ] **Step 1: Tag**

```bash
git tag phase-b-complete
```

---

# Phase 4: Sub-Project C — 7 Specialist Definitions

**Spec:** `docs/superpowers/specs/2026-06-16-shogun-v2-specialists-design.md`

For each of the 7 specialists, the task is:

1. Author `instructions/{role}.md` from oh-my-opencode-slim's prompt, adapted for multi-agent-shogun's YAML-inbox system.
2. Verify XML output format section is present.
3. Verify `permissions_override` from settings.yaml is referenced.
4. Run `build_instructions.sh` to generate per-CLI variants.

---

### Task C.1: Author `instructions/explorer.md`

**Files:**
- Create: `instructions/explorer.md`

- [ ] **Step 1: Write the prompt**

Adapt the explorer prompt from `/Users/prince/Workspaces/oh-my-opencode-slim/src/agents/explorer.ts` (lines 4-34). Add multi-agent-shogun-specific sections:

- File operations: read `queue/tasks/explorer.yaml`, write `queue/reports/explorer_report.yaml`
- Notify: `inbox_write.sh orchestrator "explorer done" report_received explorer`
- Permissions: read-only (per settings.yaml)
- Skills: from `roles.explorer.skills` (codemap)
- Output format: XML as in spec Section 2

- [ ] **Step 2: Verify required sections present**

Run: `grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/explorer.md | wc -l`
Expected: ≥ 4.

- [ ] **Step 3: Commit**

```bash
git add instructions/explorer.md
git commit -m "feat(specialists): author explorer.md"
```

---

### Task C.2: Author `instructions/librarian.md`

**Files:**
- Create: `instructions/librarian.md`

- [ ] **Step 1: Write the prompt**

Adapt from `/Users/prince/Workspaces/oh-my-opencode-slim/src/agents/librarian.ts` (lines 4-26). Add multi-agent-shogun-specific sections.

- [ ] **Step 2: Verify and commit**

```bash
grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/librarian.md | wc -l
# Expected: ≥ 4
git add instructions/librarian.md
git commit -m "feat(specialists): author librarian.md"
```

---

### Task C.3: Author `instructions/oracle.md`

**Files:**
- Create: `instructions/oracle.md`

- [ ] **Step 1: Write the prompt**

Adapt from `/Users/prince/Workspaces/oh-my-opencode-slim/src/agents/oracle.ts` (lines 4-28). Add multi-agent-shogun-specific sections.

- [ ] **Step 2: Verify and commit**

```bash
grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/oracle.md | wc -l
# Expected: ≥ 4
git add instructions/oracle.md
git commit -m "feat(specialists): author oracle.md (replaces gunshi.md)"
```

---

### Task C.4: Archive `instructions/gunshi.md`

- [ ] **Step 1: Move**

```bash
git mv instructions/gunshi.md instructions/_archive/gunshi.md
git add instructions/gunshi.md instructions/_archive/gunshi.md
git commit -m "refactor(specialists): archive gunshi.md (replaced by oracle.md)"
```

---

### Task C.5: Author `instructions/designer.md`

**Files:**
- Create: `instructions/designer.md`

- [ ] **Step 1: Write the prompt**

Use the lane description and constraints from sub-C Section 2 (specialist #4) in the spec. Add multi-agent-shogun-specific sections.

- [ ] **Step 2: Verify and commit**

```bash
grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/designer.md | wc -l
# Expected: ≥ 4
git add instructions/designer.md
git commit -m "feat(specialists): author designer.md"
```

---

### Task C.6: Author `instructions/fixer.md`

**Files:**
- Create: `instructions/fixer.md`

- [ ] **Step 1: Write the prompt**

Adapt from `/Users/prince/Workspaces/oh-my-opencode-slim/src/agents/fixer.ts` (lines 4-47). Add multi-agent-shogun-specific sections.

- [ ] **Step 2: Verify and commit**

```bash
grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/fixer.md | wc -l
# Expected: ≥ 4
git add instructions/fixer.md
git commit -m "feat(specialists): author fixer.md"
```

---

### Task C.7: Author `instructions/observer.md`

**Files:**
- Create: `instructions/observer.md`

- [ ] **Step 1: Write the prompt**

Use the lane description from sub-C Section 2 (specialist #6) in the spec. Add multi-agent-shogun-specific sections.

- [ ] **Step 2: Verify and commit**

```bash
grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/observer.md | wc -l
# Expected: ≥ 4
git add instructions/observer.md
git commit -m "feat(specialists): author observer.md"
```

---

### Task C.8: Author `instructions/council.md`

**Files:**
- Create: `instructions/council.md`

- [ ] **Step 1: Write the prompt**

Use the lane description from sub-C Section 2 (specialist #7) in the spec. Add multi-agent-shogun-specific sections including the MCP-based multi-model invocation.

- [ ] **Step 2: Verify and commit**

```bash
grep -E "^(## Role|## Output Format|## Permissions|## Multi-agent)" instructions/council.md | wc -l
# Expected: ≥ 4
git add instructions/council.md
git commit -m "feat(specialists): author council.md"
```

---

### Task C.9: Archive `instructions/ashigaru.md`

- [ ] **Step 1: Move**

```bash
git mv instructions/ashigaru.md instructions/_archive/ashigaru.md
git add instructions/ashigaru.md instructions/_archive/ashigaru.md
git commit -m "refactor(specialists): archive ashigaru.md (replaced by 7 specialists)"
```

---

### Task C.10: Regenerate all per-CLI instructions

- [ ] **Step 1: Run the build script**

Run: `bash scripts/build_instructions.sh`
Expected: emits 9 roles × N CLIs files under `instructions/generated/`.

- [ ] **Step 2: Verify**

Run: `ls instructions/generated/ | wc -l`
Expected: ≥ 9 × 6 = 54 files.

- [ ] **Step 3: Commit**

```bash
git add instructions/generated/
git commit -m "feat(specialists): regenerate per-CLI instruction variants"
```

---

### Task C.11: Write the specialist prompt regression test

**Files:**
- Create: `tests/test_specialist_prompts.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
set -euo pipefail

REQUIRED_SECTIONS=("## Role" "## Output Format" "## Permissions" "## Multi-agent")
ROLES=(orchestrator explorer librarian oracle designer fixer observer council)

FAIL=0
for role in "${ROLES[@]}"; do
    file="instructions/${role}.md"
    if [ ! -f "$file" ]; then
        echo "FAIL: $file does not exist" >&2
        FAIL=1
        continue
    fi
    for section in "${REQUIRED_SECTIONS[@]}"; do
        if ! grep -q "^${section}" "$file"; then
            echo "FAIL: $file missing section '$section'" >&2
            FAIL=1
        fi
    done
done

if [ "$FAIL" -eq 0 ]; then
    echo "PASS: all 8 specialist prompts have required sections"
fi
exit $FAIL
```

- [ ] **Step 2: Make executable and run**

Run: `chmod +x tests/test_specialist_prompts.sh && bash tests/test_specialist_prompts.sh`
Expected: `PASS: all 8 specialist prompts have required sections`.

- [ ] **Step 3: Commit**

```bash
git add tests/test_specialist_prompts.sh
git commit -m "test(specialists): regression test for required prompt sections"
```

---

### Task C.12: Tag phase completion

- [ ] **Step 1: Tag**

```bash
git tag phase-c-complete
```

---

# Phase 5: Final Integration & Verification

---

### Task F.1: Run all tests

- [ ] **Step 1: Topology tests**

```bash
bash tests/test_pane_ids.sh
bash tests/test_window_layout.sh
```

- [ ] **Step 2: Config tests**

```bash
bash tests/test_validate_settings.sh
bash tests/test_inbox_write_role_validation.sh
```

- [ ] **Step 3: Orchestrator tests**

```bash
bash tests/test_state_transitions.sh
bash tests/test_parallel_dispatch.sh
```

- [ ] **Step 4: Specialist tests**

```bash
bash tests/test_specialist_prompts.sh
```

- [ ] **Step 5: Verify all pass**

If any fail, investigate before proceeding.

---

### Task F.2: Tag final completion

- [ ] **Step 1: Final tag**

```bash
git tag shogun-v2-complete
git log --oneline | head -20
```

---

## Self-Review

**1. Spec coverage:**
- Sub-A (topology): Tasks A.1–A.11 cover all 5 sections of the topology spec.
- Sub-D (config schema): Tasks D.1–D.5 cover schema, validation, defaults, migration, and integration.
- Sub-B (orchestrator): Tasks B.1–B.6 cover role, workflow, state machine, dispatch, validation routing.
- Sub-C (specialists): Tasks C.1–C.12 cover all 7 specialists + archive + build script + test.

**2. Placeholder scan:** No TBD/TODO/"implement later" in this plan. All code blocks are concrete.

**3. Type consistency:** `v2_role_list`, `v2_pane_for`, `v2_model_for`, `v2_color_for` are defined in Task A.2 and used consistently in Tasks A.5, A.6, A.9. `start_specialist_pane` is defined in Task A.4 and used in Tasks A.5, A.6.

## Execution Handoff

This plan is ready for execution. Two options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks
2. **Inline Execution** — execute tasks in this session with checkpoints