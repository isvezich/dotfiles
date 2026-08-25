# 02 — state helper: commit-pinned approval + graph validation

**What to build:** the approval-durability and validation commands on
`workflow-state.sh`, so `/work` can refuse unapproved or drifted work.

**Blocked by:** 01 — extends the same helper + ledger.

**Status:** done

- [ ] `approve-spec <sha>` — record `spec_commit: <sha>`, transition to
      `spec-approved`.
- [ ] `approve-tickets <sha> <manifest-path...>` — record `tickets_commit`, the
      active-ticket **manifest** (the `features/<slug>/*.md` paths), and
      transition to `ready-to-work`.
- [ ] `check-ready` — for `/work`: exit 0 only if `status == ready-to-work`, the
      feature branch tip matches/descends from `tickets_commit`, AND each
      manifest ticket's content digest matches the approved digest. Any drift →
      non-zero with a message naming what drifted (require re-approval).
- [ ] `graph-validate <slug>` — reject missing/duplicate ticket ids,
      self-dependencies, cycles, unknown statuses, and no-executable-frontier;
      non-zero with the specific defect.
- [ ] Tests: approve-spec/tickets record pins; check-ready passes when clean,
      fails on status/commit/digest drift (three separate cases); graph-validate
      catches a cycle, a dup id, an unknown status, and a no-frontier graph.
