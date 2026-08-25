---
name: ship
disable-model-invocation: true
description: Finish a feature — a whole-feature review over the entire branch, fresh full-suite verification, then the merge/PR/keep integration menu. Thin router over requesting-code-review + reviewers:codex + Superpowers verification-before-completion + finishing-a-development-branch. One human gate. Invoke explicitly as /ship.
when_to_use: When the feature's tickets are all done and you're ready to review the whole branch, verify, and integrate. The user runs /ship. Follows /work.
version: 3.1.0
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
   `**Base:**` from the spec (the `<feature-base>` fork-point), then dispatch
   `superpowers:requesting-code-review` (Claude, with the
   `~/.claude/skills/dev-workflow/smell-baseline.md` Fowler lens) **and**
   `reviewers:codex --base <feature-base>` together in one message. This restores
   cross-ticket coverage and writes the push-gate sentinel for the full outgoing
   diff (per-ticket sentinels won't match it). Resolve every blocking finding
   (re-review after fixes) before continuing; a scope-changing finding sends you
   back to `/feature`'s gate.

3. **Fresh verification** — invoke `superpowers:verification-before-completion`:
   run the full suite now and capture the actual output; don't rely on earlier
   per-ticket runs.

4. **Finish the branch** — invoke `superpowers:finishing-a-development-branch`:
   it presents the merge / PR / keep menu. **HUMAN GATE ↯ — the integration
   choice is the user's.** Outward-facing: no merge/push without their explicit
   choice; honor the CLAUDE.md refspec rule on any push.
