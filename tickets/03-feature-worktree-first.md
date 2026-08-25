# 03 — /feature: worktree-first + commit-pinned gates

**What to build:** rewrite `/feature` so it creates the branch+worktree before
writing artifacts, writes spec/ADRs/tickets into the feature namespace, commits
at each gate, and records the commit-pins via the helper.

**Blocked by:** 02 — uses approve-spec / approve-tickets / graph-validate.

**Status:** done

- [ ] Step 1: create the feature branch + worktree
      (`superpowers:using-git-worktrees`) BEFORE any artifact; `cd` there; ledger
      `status: designing`, record feature slug + branch.
- [ ] Keep the invocability fix: invoke model-invocable `grilling` /
      `domain-modeling` / `research` / `prototype` / `codebase-design`; inline
      the user-only spec/tickets synthesis.
- [ ] Write `docs/specs/<slug>.md` + ADRs; **commit**; then SPEC GATE ↯; on
      approval `workflow-state.sh approve-spec <sha>`.
- [ ] Write tickets to `tickets/features/<slug>/<NN>-<slug>.md` (What to build /
      Blocked by / Status: ready-for-agent / acceptance); **commit**; run
      `graph-validate <slug>`; then TICKET GATE ↯; on approval
      `approve-tickets <sha> <manifest...>` → `status: ready-to-work`.
- [ ] Update the frontmatter/description to match the new flow.
