---
name: ship
disable-model-invocation: true
description: Finish a feature — a whole-feature review over the entire branch (host-model via requesting-code-review + a host-aware cross-model reviewer: reviewers:codex in Claude Code, claude -p headless in Codex), fresh full-suite verification, then the merge/PR/keep integration menu. One human gate. Invoke explicitly as /ship.
when_to_use: When the feature's tickets are all done and you're ready to review the whole branch, verify, and integrate. The user runs /ship. Follows /work.
version: 3.2.0
languages: all
---

# /ship — verify and integrate

A human-driven checklist. Shared rules:
`~/.claude/skills/dev-workflow/workflow.md`. Call the helper by full path:
`bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh` (Bash calls don't
share shell variables).

## Steps

1. **Confirm the feature is done and the tree is clean** —
   `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets <feature-slug>`
   must show `N/N done` with N > 0, **and** `git status --porcelain` must be
   empty. If `0/0` (no feature here), some ticket isn't `done`, or the tree is
   dirty (an uncommitted status flip), stop / return to `/work` — don't ship
   partial or uncommitted work.

2. **Whole-feature review** — over the entire branch, not per-ticket: read
   `**Base:**` from the spec (the `<feature-base>` fork-point) and **validate it**
   — `git rev-parse --verify "<feature-base>^{commit}"` and
   `git merge-base --is-ancestor <feature-base> HEAD`; if it isn't a real ancestor
   (e.g. after a rebase), stop and return through `/feature`'s spec gate with a
   human-picked base rather than guessing. Caveat (accepted, human-owned): passing
   ancestry is necessary but not sufficient — if the feature was rebased onto or
   merged a *newer* target since `Base` was recorded, the old `Base` stays an
   ancestor while `<feature-base>..HEAD` balloons to include unrelated upstream
   commits. If that's happened, refresh `Base` via the spec gate before reviewing.
   Then dispatch **two reads together in one message** (see `Review model` in
   workflow.md): your host's own model via `superpowers:requesting-code-review`
   (with the `~/.claude/skills/dev-workflow/smell-baseline.md` Fowler lens **and**
   the approved spec + each ticket's acceptance criteria in the brief, so it checks
   spec compliance, not just diff defects), **and** the **cross-model reviewer for
   your host** over `<feature-base>..HEAD` — `reviewers:codex --base <feature-base>`
   in Claude Code, or `git diff <feature-base>..HEAD | claude -p '<review brief>'`
   in Codex (never `reviewers:codex` from inside Codex — same model as the host).
   This restores cross-ticket coverage; on the Claude Code host the `reviewers:codex`
   pass also writes the push-gate sentinel for this checkout's
   `<feature-base>..HEAD` diff (per-ticket sentinels won't match it; the sentinel
   attests the review ran, it is not bound to the push's refs). A review only
   counts if **both** reads complete over that range — a plugin/network/timeout
   failure blocks, it is not "no findings."
   Resolve every blocking finding, committing each fix and confirming a clean tree
   before re-review; a scope-changing finding sends you back to `/feature`'s
   **spec** gate (step 5). When both pass, **note `REVIEW_HEAD` = `git rev-parse
   HEAD`** (a literal sha held in context). On a *resumed* session where
   `REVIEW_HEAD` was lost and the diff is unchanged, `reviewers:codex` returns
   `cached; gate already unblocked` instead of a fresh verdict — delete the
   wrapper-named `/tmp/review-gate-reviewed-*` cache file and re-run so you get a
   real review, don't treat the cache hit as a pass.

3. **Fresh verification** — invoke `superpowers:verification-before-completion`:
   run the full suite now and capture the actual output; don't rely on earlier
   per-ticket runs. **If a fix is needed, commit it and return to step 2** — the
   fix is unreviewed and changes `HEAD`, so re-run the whole-feature review before
   proceeding.

4. **Finish the branch** — first confirm `git status --porcelain` is empty **and
   `git rev-parse HEAD` == `REVIEW_HEAD`** (integration must be the exact commit
   that passed review; if it drifted, go back to step 2). Then invoke
   `superpowers:finishing-a-development-branch`: it presents the merge / PR / keep
   menu. **HUMAN GATE ↯ — the integration choice is the user's.** Outward-facing:
   no merge/push without their explicit choice; honor the CLAUDE.md refspec rule
   on any push.
