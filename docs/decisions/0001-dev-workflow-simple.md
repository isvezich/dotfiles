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
find "nothing stops X." Rounds 8–9 fixed the concrete bugs and adopted the
**cheap invariants** a reviewer flagged — because they're small guards, not a
state machine:

- **Adopted (cheap guards, not machinery):** helper anchors all paths at
  `git rev-parse --show-toplevel` and validates the slug grammar; `**Base:**` is
  verified (`rev-parse --verify` + `merge-base --is-ancestor`); `/ship` captures
  an in-context `REVIEW_HEAD` and refuses to finish unless `HEAD == REVIEW_HEAD`
  on a clean tree; `/work`+`/ship` re-review after any fix; reviewer briefs carry
  the ticket/spec so review checks compliance, not just diff defects.

Still **declined as YAGNI for a solo workflow** and accepted as risks the human
owns, not defects to automate:

- **Push-gate attestation.** The review sentinel attests *a review of the current
  checkout ran*; it is not bound to the push's refs or remote tip and its `/tmp`
  key is same-user forgeable. A real remote-SHA `pre-push` hook is not built —
  the gate is documented as a process aid, not a security boundary.
- **Persistent / cross-session review state.** The `REVIEW_HEAD` guard lives in
  the coordinator's context, not on disk; a resumed session with no in-context
  reviewed sha simply re-runs the whole-feature review.
- **Feature/branch manifest & stacked features.** No on-disk manifest of
  branch/target-ref, and no stacked-feature semantics. Convention is one feature
  per branch with a `**Base:**` in the spec; the human keeps them consistent.
- **Non-linear ticket dependencies.** `Blocked by` is honored, but the helper
  does not build/validate the graph; work is sequential.
- **Workflow-level acceptance harness.** Only the helper is unit-tested. In lieu
  of an end-to-end suite, the seams to smoke-check by hand when the routers change
  are: invocation from a repo subdirectory, a dirty triage handoff, resume from
  `in-progress`, a malformed slug/dep id, a rebased/non-ancestor `Base`, a
  reviewer timeout, a verification failure after review, a scope-changing finding,
  and final `HEAD` drift before finishing.

Not adopted, recorded for reconsideration: handing the whole ticket set to
`subagent-driven-development` as one plan (instead of per-ticket primitives)
could subsume `/work`'s orchestration — but it collapses the per-ticket human
control and moves finishing inside SDD, which fights the four-verb human-gated
design; and pinning exact versions of all three required plugins (only a
Superpowers lower bound is recorded today).

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
