---
name: ship
disable-model-invocation: true
description: Finish a feature — fresh full-suite verification, then present the merge/PR/keep integration menu. Thin router over Superpowers verification-before-completion + finishing-a-development-branch. One human gate. Invoke explicitly as /ship.
when_to_use: When the feature's tickets are all done and you're ready to verify and integrate. The user runs /ship. Follows /work.
version: 3.0.0
languages: all
---

# /ship — verify and integrate

A human-driven checklist. Shared rules:
`~/.claude/skills/dev-workflow/workflow.md`. `W=~/.claude/skills/dev-workflow/scripts/workflow-state.sh`

## Steps

1. **Confirm the tickets are done** — `bash $W tickets` should show `N/N done`
   with N > 0. If `0/0` (no feature here) or some are not done, stop / return to
   `/work` — don't ship partial work.

2. **Fresh verification** — invoke `superpowers:verification-before-completion`:
   run the full suite now and capture the actual output; don't rely on earlier
   per-ticket runs.

3. **Finish the branch** — invoke `superpowers:finishing-a-development-branch`:
   it presents the merge / PR / keep menu. **HUMAN GATE ↯ — the integration
   choice is the user's.** Outward-facing: no merge/push without their explicit
   choice; honor the CLAUDE.md refspec rule on any push.
