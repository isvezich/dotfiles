<!-- ABOUTME: ADR recording the decision to keep the dev-workflow a simple manual-aid checklist. -->
<!-- ABOUTME: A robust-state-machine attempt was abandoned after repeated cross-model review showed it non-convergent. -->

# ADR 0001 — the dev-workflow is a manual-aid, not a state machine

**Status:** accepted

## Context

The `triage`/`feature`/`work`/`ship` skills are a personal, single-user dev
workflow. An attempt to make the tracker a *robust state machine* — git-common-dir
ledger, separate intake/feature namespaces, commit-pinned approval with content
digests, atomic transactional lifecycle commands, closed approval bundles,
resume/crash-consistency, a dependency-graph validator — was reviewed by an
independent cross-model reviewer (Codex/gpt-5.6-sol) across **six** passes. Every
pass surfaced new correctness gaps; the design kept demanding more
distributed-systems rigor (per-ticket TOCTOU revalidation, git-tree-derived
manifests instead of filesystem hashes, a single atomically-swapped state record
or generation directories, a formal input grammar with path canonicalization).

## Decision

**Keep the workflow a simple, human-driven checklist over a flat local tracker.**
- The routers are checklists a human drives through explicit gates; they invoke
  the tuned upstream skills (and inline the user-only Matt Pocock ones).
- The tracker is flat `tickets/<NN>-<slug>.md` (with a `**Status:**` line) plus
  `docs/specs/` and `docs/decisions/`. The helper does only `init` (scaffold) and
  `tickets` (list + done/total).
- No ledger, no commit-pinning, no approval digests, no transactional state
  machine, no worktree-first ceremony, no per-feature namespaces.

## Rationale

- **YAGNI.** For a solo workflow the enforced-integrity properties (crash
  recovery, tamper-evident approval, multi-feature isolation) are rarely
  exercised and never worth a crash-consistent bash state machine.
- **Non-convergence.** Six review rounds did not converge — each layer of
  machinery added surface for the next round. A checklist has almost no such
  surface: the whole class of state-machine bugs (ledger corruption,
  digest/status contradictions, illegal transitions, TOCTOU) simply does not
  exist.
- **The value was never the state machine** — it's the *gates* and the *dual-model
  review* in `/work`. Those are preserved.

## Consequences

- The workflow enforces nothing; the human drives the gates and owns integrity.
- Superseded and removed: the v2 spec (`docs/specs/dev-workflow-v2.md`), the v2
  ADR, and the v3 redesign tickets.
- The dogfooding exercise's real payoff stands on its own: the cross-model review
  caught defects the same-model reviews repeatedly missed — the strongest reason
  to keep `reviewers:codex` in the `/work` panel.
