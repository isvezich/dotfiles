<!-- ABOUTME: ADR for the dev-workflow v2 state model (robust namespaces + commit-pinned approval + worktree-first). -->
<!-- ABOUTME: Records the decisions taken after four cross-model review passes on the v1 flat design. -->

# ADR 0001 — dev-workflow v2 state model

**Status:** accepted

## Context

The v1 dev-workflow skills executed but their state model was unsafe beyond the
solo/linear case (Codex review): a flat `tickets/` namespace conflated intake,
active feature, and history; approvals lived only in conversation; planning
happened before worktree isolation; and the recovery state machine was
incomplete. Grilled decisions: **full robust state model**, **separate intake vs
feature dirs**, **commit-pinned approval**, **worktree-first with a git-common-dir
ledger**.

## Decisions

1. **Git-common-dir ledger.** Runtime state lives at
   `$(git rev-parse --git-common-dir)/dev-workflow/state.yaml` — one copy shared
   by all worktrees, never versioned — so recovery works from any checkout.
2. **Separate namespaces.** `tickets/inbox/` (triage) vs
   `tickets/features/<slug>/` (execution); `/work` + `/ship` act only on the
   active feature's dir. Kills wontfix-blocks-shipping, cross-feature
   contamination, and `NN` collisions.
3. **Worktree-first.** `/feature` creates the branch + worktree before writing
   any artifact; spec/tickets are written and committed there.
4. **Commit-pinned approval.** Gates commit the spec/tickets and record
   `spec_commit`/`tickets_commit` + a `path→sha256` manifest; `/work`'s
   `check-ready` refuses unless `ready-to-work`, HEAD descends from the pin, and
   no digest drifted. Durable + drift-detecting; git is the record.
5. **Explicit state machine** with validated transitions (helper rejects illegal
   ones), plus reconciliation rules (git=commits, manifest=scope, ledger=phase).
6. **Dependency-graph validation** at the ticket gate (Kahn's): reject dup ids,
   self-deps, unknown refs/statuses, cycles, no-frontier.
7. **Data, not instructions.** Ledger, specs, ADRs, tickets are untrusted
   structured inputs; never execute their prose; renewed approval for
   scope-changing content.
8. **User-only skills inlined.** `to-spec`/`to-tickets`/`triage` are
   `disable-model-invocation: true`, so the routers inline their interview-free
   logic and invoke only model-invocable primitives (grilling, domain-modeling…).

## Consequences

- One active feature per repo (documented limitation).
- Guardrail, not adversary-proof (unsigned ledger; `--no-verify` bypasses hooks).
- `workflow-state.sh` grows from scaffold+read into a validated state machine
  (`set-status`, `set`, `approve-spec`, `approve-tickets`, `check-ready`,
  `graph-validate`, `tickets --feature`).
- Migration: v1's in-tree `.ai/workflow.yaml` → git-common-dir; flat `tickets/*.md`
  → `inbox/` + `features/<slug>/`.
