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

**Keep the workflow human-driven checklists — plus the smallest set of
coordination identifiers a multi-ticket happy path actually needs — but NOT a
state machine.** The rejected middle ground the first draft skipped is adopted
here: it is coordination metadata, not transactional machinery.
- The routers are checklists a human drives through explicit gates; they invoke
  the tuned upstream skills (and inline the user-only Matt Pocock ones). Reviews
  go through the public `superpowers:requesting-code-review` interface.
- Intake is separate from execution: triage records in `requests/`, execution
  tickets in per-feature `tickets/<feature-slug>/`, so a deferred/rejected
  request never blocks a feature's `done/total` and ids can't collide across
  features.
- One provenance line — `**Base:** <fork-point>` in the spec — lets `/work`
  review per ticket and `/ship` review the **whole branch** (and produce the
  push-gate sentinel for the full outgoing diff).
- The helper still does only `init` (scaffold, incl. `requests/`) and
  `tickets [feature-slug]` (list + done/total for one feature).
- Still **no** ledger, commit-pinning, approval digests, transactional lifecycle
  commands, worktree-first ceremony, or dependency-graph validator.

## Rationale

- **YAGNI, bounded.** For a solo workflow the enforced-integrity properties
  (crash recovery, tamper-evident approval) are never worth a crash-consistent
  bash state machine. But *some* structure — scoped intake, per-feature ids, a
  base ref — is needed for the plain multi-ticket path to work at all; the first
  radical cut removed too much and the happy path couldn't compose.
- **Non-convergence of the machine, not of the need.** Six review rounds of the
  *state machine* did not converge — each layer added surface for the next. The
  checklist has almost no such surface. It does **not** make correctness free:
  humans and concurrent file edits can still produce contradictory statuses,
  stale dependencies, or work against a changed spec. The design accepts those
  risks rather than automating them away.
- **The value was never the state machine** — it's the *gates* and the
  *dual-model review*. Those are preserved and, in `/ship`, extended to the whole
  feature.

## Accepted risks / explicitly declined machinery

A prose checklist cannot *enforce* invariants, so a rigorous reviewer will always
find "nothing stops X." Round-8 review confirmed the concrete bugs are fixed
(base-ref provenance, commit-before-review, `adopted` intake status, scope→spec
gate) but flagged deeper enforcement gaps. These are **declined as YAGNI for a
solo workflow** and accepted as risks the human owns, not defects to automate
away:

- **Push-gate attestation.** The review sentinel attests *a review of the current
  checkout ran*; it is not bound to the push's refs or remote tip and its `/tmp`
  key is same-user forgeable. A real remote-SHA `pre-push` hook is not built —
  the gate is documented as a process aid, not a security boundary.
- **Feature/branch manifest.** No retained target-ref, ancestry validation at
  `/ship`, or stacked-feature semantics. Convention is one feature per branch,
  one canonical `<slug>` for `docs/specs/<slug>.md` and `tickets/<slug>/`, and a
  `**Base:**` fork-point in the spec; the human keeps them consistent.
- **Immutable review state.** No `REVIEW_HEAD` tracking that auto-invalidates on
  a later commit; instead `/work` and `/ship` require a clean tree and committed
  fixes before every (re-)review.
- **Workflow-level acceptance harness.** Only the helper is unit-tested; the
  router prose is not driven by an end-to-end scenario suite.

## Consequences

- The workflow enforces nothing; the human drives the gates and owns status and
  commit integrity by hand.
- Superseded and removed: the v2 spec (`docs/specs/dev-workflow-v2.md`), the v2
  ADR, and the v3 redesign tickets.
- The dogfooding exercise's real payoff stands on its own: the cross-model review
  caught defects the same-model reviews repeatedly missed — including the flat
  tracker's intake/execution conflation and a broken helper reference in this
  very simplification — the strongest reason to keep `reviewers:codex` in the
  review panel.
