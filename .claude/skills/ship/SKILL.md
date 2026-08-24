---
name: ship
description: Finish a feature — fresh full-suite verification, then present the merge/PR/keep integration menu and clean up the worktree. Thin router over Superpowers verification-before-completion + finishing-a-development-branch. One human gate at the integration choice. Invoke explicitly as /ship.
when_to_use: When all of a feature's tickets are done and you are ready to verify and integrate. The user runs /ship. Follows /work.
version: 1.0.0
languages: all
---

# /ship — verify and integrate

Thin router. Shared rules are in `~/.claude/skills/dev-workflow/workflow.md`.

## Steps

1. **Confirm the tickets are all closed:**
   ```bash
   bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets
   ```
   Expect `N/N done`. If not, return to `/work` — do not ship partial work.
   Set `.ai/workflow.yaml` `status: shipping`.

2. **Fresh verification** — invoke `superpowers:verification-before-completion`.
   No completion claim without fresh evidence: run the full suite now, capture
   the actual output, do not rely on earlier per-ticket runs.

3. **Finish the branch** — invoke `superpowers:finishing-a-development-branch`:
   verify tests, detect the environment, and present the integration menu.
   **HUMAN GATE ↯ — the merge / PR / keep decision is the user's.** Integration
   is outward-facing; do not merge or push without the user's explicit choice.
   Honor the CLAUDE.md refspec rule on any push (`git push <remote>
   <localref>:refs/heads/<remote-branch>`).

4. **Clean up + reset state** — after the chosen integration, clean up the
   worktree and reset `.ai/workflow.yaml` to `status: idle` with `feature`,
   `branch`, and `current_ticket` cleared. Prune closed-out notes; keep only
   what a future session needs.
