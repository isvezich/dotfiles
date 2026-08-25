# 05 — /work: approval-guarded, per-feature, pinned reviews

**What to build:** rewrite `/work` to refuse unapproved/drifted work, operate
only on the active feature, pin review ranges, and terminate (not spin) on
blocked/no-frontier.

**Blocked by:** 02, 03 — needs `check-ready`/pins from the helper and the
approved manifest from `/feature`.

**Status:** ready-for-agent

- [ ] Start: run `workflow-state.sh check-ready`; refuse to proceed on non-zero
      (unapproved, wrong commit, or digest drift) with the helper's message.
      Then `status: working`.
- [ ] Operate ONLY on the active feature's `tickets/features/<slug>/` (from the
      ledger manifest) — never inbox or other features.
- [ ] Per ticket: capture BASE (pre-implementer commit) → fresh implementer
      subagent + `superpowers:test-driven-development` → review the exact
      `BASE..HEAD` range with the Superpowers reviewer + `reviewers:codex --base
      <BASE>` + the Fowler smell lens → `verification-before-completion`. Close
      only when reviews returned, findings resolved, verification passes. Do NOT
      invoke subagent-driven-development; do NOT finish the branch.
- [ ] Renewed gate: if resolving a finding changes approved scope
      (problem/spec/acceptance/deps/out-of-scope) → stop for re-approval.
- [ ] Terminate with a durable `blocked` reason + handoff on: blocked ticket, no
      executable frontier, dependency cycle, or review timeout.
- [ ] Update frontmatter/description.
