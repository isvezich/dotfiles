---
name: ship
disable-model-invocation: true
description: Finish the active feature — fresh full-suite verification, then the merge/PR/keep integration gate, with state transitions and cleanup conditional on the outcome. Thin router over Superpowers verification-before-completion + finishing-a-development-branch. One human gate. Invoke explicitly as /ship.
when_to_use: When the active feature's tickets are all done and you're ready to verify and integrate. The user runs /ship. Follows /work.
version: 2.0.0
languages: all
---

# /ship — verify and integrate (v2)

Router. Shared rules + the v2 state model are in
`~/.claude/skills/dev-workflow/workflow.md`. `W=~/.claude/skills/dev-workflow/scripts/workflow-state.sh`

## Steps

1. **Confirm a completed feature (active feature only):** `bash $W tickets
   --feature <slug>` (slug from the ledger). Require **all three**: a `feature`
   in flight with `status: working`, `N/N done`, **and N > 0**. A bare `0/0`
   (no feature / wrong repo) is NOT shippable — stop. Some not-done → back to
   `/work`. (Do NOT transition to `shipping` yet — verify first, next step.)

2. **Fresh verification FIRST** — invoke `superpowers:verification-before-completion`:
   run the full suite now, capture actual output; don't rely on per-ticket runs.
   Only when it passes: `bash $W set-status shipping`. If it fails, `bash $W
   set-status working` (or `blocked` with a reason) and return to `/work` — do
   not enter `shipping` on a red suite (there's no clean way back out mid-ship).

3. **Finish the branch** — invoke `superpowers:finishing-a-development-branch`:
   present the integration menu. **HUMAN GATE ↯ — merge / PR / keep is the
   user's call.** Outward-facing: no merge/push without their explicit choice.
   Honor the CLAUDE.md refspec rule on any push.

4. **Transition + cleanup — conditional on the outcome:**
   - **Merged** (branch finished & removed): remove the worktree, then
     `bash $W set-status idle` and clear the pins/feature:
     `bash $W set feature null; bash $W set branch null; bash $W set current_ticket null`
     (`spec_commit`/`tickets_commit`/`manifest` are reset on the next feature's
     approval). The ledger is in the git-common-dir, so this is checkout-independent.
   - **PR opened:** `bash $W set-status pr-open` — keep the worktree/branch
     (finishing-a-development-branch preserves them for PR feedback). Do NOT reset.
   - **Keep the branch:** `bash $W set-status parked` — keep the worktree/branch.
   - On a later confirmed external merge of the PR: `bash $W set-status idle` +
     clear as in the merged case.
