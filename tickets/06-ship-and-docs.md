# 06 — /ship state transitions + docs/ADR/migration

**What to build:** rewrite `/ship` for per-feature completion + the full state
machine, and bring all docs in line (workflow.md, README, ADR, migration).

**Blocked by:** 02, 05 — needs the helper transitions and the /work flow.

**Status:** done

- [ ] `/ship` evaluates ONLY the active feature (`tickets --feature <slug>`);
      requires all done + N>0 + `status: working`→`shipping`. Fresh verification.
- [ ] `finishing-a-development-branch` → integration gate ↯. Then conditional:
      merged → `set-status idle` (clear feature/spec/branch/pins, remove
      worktree); PR → `pr-open` (preserve worktree); keep → `parked` (preserve).
      Ledger lives in git-common-dir, so the reset is checkout-independent.
- [ ] `workflow.md`: rewrite for v2 (namespaces, git-common-dir ledger,
      worktree-first, commit-pinned approval, state machine + transition table,
      reconciliation, renewed-gate, data-not-instructions for specs/tickets too).
- [ ] `README`: required plugins (superpowers, mattpocock-skills, reviewers) with
      the `gni-skills` marketplace-add step; codex-gate guidance → `--base` for
      branch pushes (not `--commit HEAD`); note the new namespaces/ledger.
- [ ] `docs/decisions/`: ADR recording the v2 state model (supersede any v1 ADR).
- [ ] Migration note: `.ai/workflow.yaml` → git-common-dir; flat `tickets/*.md`
      → `inbox/` + `features/<slug>/`.
