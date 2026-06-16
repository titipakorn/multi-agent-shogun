# Sub-Project B: Shogun V2 Orchestrator Design

**Date:** 2026-06-16
**Sub-project:** B of 4 in the Specialist Agent Team Revamp
**Status:** Approved (pending spec self-review)
**Depends on:** Sub-A (topology), Sub-D (config schema)
**Enables:** Sub-C (specialists)

## Goal

Replace the existing karo role with a full oh-my-opencode-slim-style orchestrator that owns dispatch + validation routing. The orchestrator decomposes cmds into specialist-routed tasks, dispatches in parallel, reconciles reports, routes validation to oracle/council/designer, and reports final outcomes to shogun. Mirrors oh-my-opencode-slim's orchestrator pattern.

## Orchestrator Role & Prompt Architecture

### Core responsibilities

- Receive cmds from shogun via `queue/inbox/orchestrator.yaml`
- Decompose into specialist-routed tasks
- Dispatch via `inbox_write.sh {role} ...` (one or more specialists in parallel)
- Wait for specialist reports (event-driven; no polling)
- Route validation: send completed work to oracle for review, council for consensus, designer for visual sign-off
- Report final outcome to shogun via `queue/inbox/shogun.yaml`
- Update `dashboard.md` (orchestrator owns this; gunshi's role folded in)

### Prompt structure (saved to `instructions/orchestrator.md`)

```markdown
# Orchestrator Agent

## Role
You are the workflow manager. You plan, schedule, dispatch, monitor, reconcile,
and verify specialist work. You do NOT execute work yourself.

## Available Specialists (lane rules)

| Role | Lane | Permissions | When to use |
|------|------|-------------|-------------|
| @explorer | Fast codebase recon | read_files | Need to discover what exists before planning |
| @librarian | Web/docs research | read_files | Library API, version-specific behavior, external knowledge |
| @oracle | Architecture & review | read_files | Strategic decisions, code review, simplification |
| @designer | UI/UX design | read+write_files | User-facing interfaces, polish, design systems |
| @fixer | Bounded implementation | read+write_files | Headless/mechanical implementation |
| @observer | Visual/media analysis | read_files | Screenshots, PDFs, image inspection |
| @council | Multi-model consensus | read_files | High-stakes decisions needing multiple opinions |

## Workflow Phases

1. **Understand** — Parse the cmd's purpose and acceptance_criteria
2. **Path Selection** — Decide the implementation path (cost/speed/quality)
3. **Delegation Check** — Apply lane rules (rules-based, then LLM judgment for edge cases)
4. **Plan & Parallelize** — Build work graph; identify parallel opportunities
5. **Dispatch** — Send inbox_write to specialists. Multiple in parallel when independent.
6. **Reconcile** — When reports arrive, route validation:
   - Implementation tasks → @oracle for review
   - Architectural decisions → @council for consensus
   - UI/UX work → @designer for visual sign-off
7. **Verify** — Run relevant checks (tests, builds, scope review)
8. **Report** — Update dashboard.md and inbox_write shogun

## Dispatch Rules (hybrid)

### Rule-based routing (preferred)
- "find X / where is X / search for" → @explorer
- "what's the latest API for X / how does library Y work" → @librarian
- "review this code / is this design right / simplify" → @oracle
- "design the UI / improve the look" → @designer
- "implement X / write the code / fix the bug" → @fixer
- "analyze the screenshot / describe the image" → @observer
- "we need consensus / multiple opinions / high-stakes decision" → @council

### LLM judgment (ambiguous cases)
If no rule matches cleanly, decide based on:
- Read/write intent (read_only specialists vs fixer/designer)
- Domain (visual = observer, research = librarian, code = explorer/oracle)
- Risk level (high-risk = council, low-risk = specialist)

### Fallback
If still ambiguous, ask shogun via dashboard 🚨 before dispatching.

## Background Task Discipline
- Use `inbox_write.sh {role} "..." task_assigned orchestrator` for each dispatch
- Dispatch multiple in parallel; do not wait between dispatches when independent
- Track each in `queue/tasks/orchestrator.yaml` (parallel_tasks list)
- Stop after dispatch; event-driven wakeup when reports arrive

## Validation Routing
- Implementation report → @oracle (review)
- Architecture/design report → @council (consensus)
- Visual work → @designer (design QA)
- Read-only specialist report → no validation needed (already read-only)
```

## Workflow State, Files, and Recovery

### Files (orchestrator owns)

- `queue/inbox/orchestrator.yaml` — incoming cmds from shogun
- `queue/tasks/orchestrator.yaml` — orchestration state (parallel tasks, dependencies, validation queue)
- `queue/reports/orchestrator_report.yaml` — final reports to shogun
- `dashboard.md` — orchestrator updates this directly (Karo's role preserved)
- `queue/inbox/shogun.yaml` — sends final report to shogun

### State machine

```
state: idle
  → cmd_received: write to queue/inbox/orchestrator.yaml; state = analyzing
state: analyzing
  → read cmd; build plan; state = dispatching
state: dispatching
  → inbox_write to N specialists in parallel; state = awaiting_reports
state: awaiting_reports
  → on report received: state = validating (if validation needed) or reconciling
state: validating
  → route to oracle/council/designer for review; state = reconciling
state: reconciling
  → integrate results; check acceptance_criteria; state = done or failed
state: done
  → write queue/reports/orchestrator_report.yaml; inbox_write shogun; state = idle
state: failed
  → write report with reason; inbox_write shogun with failure; state = idle
```

### Task YAML structure (orchestrator's view)

```yaml
orchestration:
  parent_cmd: cmd_001
  started_at: "2026-06-16T10:00:00"
  state: awaiting_reports
  parallel_tasks:
    - task_id: subtask_001a
      role: explorer
      status: assigned
      dispatched_at: "2026-06-16T10:00:30"
      report_received_at: null
      validation_route: null
    - task_id: subtask_001b
      role: fixer
      status: assigned
      dispatched_at: "2026-06-16T10:00:30"
      report_received_at: null
      validation_route: oracle
  validation_queue:
    - task_id: subtask_001a
      role: oracle
      status: assigned
  acceptance_criteria: []
  purpose: ""
```

### Recovery from /clear or compaction

1. Read `queue/tasks/orchestrator.yaml` → current state
2. Read `queue/inbox/orchestrator.yaml` → unread messages
3. Read `queue/reports/{role}_report.yaml` for all dispatched roles → check for unprocessed reports
4. Resume from current state; do not re-dispatch already-completed tasks

### Error handling

- Specialist report not arriving within timeout → check pane activity; if dead, restart and re-dispatch
- Validation report not arriving → escalate to shogun via dashboard 🚨
- Multiple validation rounds → orchestrator decides if 2nd round needed; if 3rd needed, escalate

## Testing

### Unit tests

- `test_dispatch_rules.sh` — feeds task descriptions through rule-based routing; expects correct specialist
- `test_state_transitions.sh` — verifies state machine transitions (idle → analyzing → dispatching → awaiting → ...)
- `test_yaml_schema.sh` — validates `queue/tasks/orchestrator.yaml` schema

### Integration tests

- `test_parallel_dispatch.sh` — orchestrator dispatches 3 specialists in parallel; verifies all 3 wakeups sent within 1 second
- `test_validation_routing.sh` — implementation report → oracle; high-stakes decision → council
- `test_report_reconciliation.sh` — multi-specialist reports arrive; orchestrator integrates
- `test_recovery.sh` — orchestrator recovers from /clear mid-dispatch; resumes correctly

### E2E tests

- Lord → Shogun → Orchestrator → 3 parallel specialists (explorer + fixer + observer) → Orchestrator → Oracle (validation) → Orchestrator → Shogun → Lord
- All steps verified by reading YAMLs
- Regression test for 2026-02-13 incident: orchestrator never confuses its role with specialist roles

## Out of Scope (handled by later sub-projects)

- Sub-C: The 7 specialist prompts (explorer, librarian, oracle, designer, fixer, observer, council)

## Open Questions for Later Phases

1. Should the orchestrator self-/clear when context is exhausted? Karo has this rule; orchestrator should preserve it.
2. Does the orchestrator need to write a daily log entry (karo does)? Confirm in sub-C testing.
3. What happens when council's multi-model consensus disagrees with orchestrator's plan? Orchestrator follows council (council wins).