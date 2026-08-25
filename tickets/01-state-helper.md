# 01 — state helper: git-common-dir ledger + validated state machine

**What to build:** rework `dev-workflow/scripts/workflow-state.sh` from a
scaffold+read script into the validated state machine the v2 design needs. This
is the foundation every router uses.

**Blocked by:** None — can start immediately.

**Status:** done

- [ ] Ledger lives at `$(git rev-parse --git-common-dir)/dev-workflow/state.yaml`
      (shared across worktrees; `BITBOT_GATE_DIR`-style `WORKFLOW_STATE_DIR`
      override for tests). `init` creates it + `tickets/inbox/` +
      `tickets/features/`; fails closed on any mkdir/write error.
- [ ] `show` prints the ledger; errors if absent.
- [ ] `set-status <state>` — atomic (temp+mv); **rejects illegal transitions**
      per the spec's transition table (idle→triaging→designing→spec-approved→
      ready-to-work→working→shipping→{idle|pr-open|parked}, +blocked, any→idle).
- [ ] `tickets --feature <slug>` — lists/counts ONLY
      `tickets/features/<slug>/*.md` over execution states
      (`ready-for-agent|in-progress|done|blocked`); `done` vs total; ignores
      inbox + terminal triage states.
- [ ] Reconciliation helper: given the branch + manifest, re-derive phase when
      the ledger disagrees (git=commits, manifest=scope, ledger=phase).
- [ ] Repo bash style (two ABOUTME lines, `set -uo pipefail`, atomic writes).
- [ ] `tests/dev-workflow/test.sh` rewritten: ledger location, init failure,
      each legal transition, every illegal transition rejected, per-feature
      ticket scoping (inbox + other features excluded), interruption/atomicity.
