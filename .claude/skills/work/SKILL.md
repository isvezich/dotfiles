---
name: work
disable-model-invocation: true
description: Execute the approved tickets via Superpowers primitives per ticket (fresh implementer + TDD + a Claude review + cross-model Codex review + verification) — NOT subagent-driven-development, which would finish the branch after ticket 1. Fowler smell baseline as an extra review lens. Autonomous between tickets; finishing is /ship's job. A human-driven checklist. Invoke explicitly as /work.
when_to_use: When a feature has an approved spec and local tickets and you're ready to implement. The user runs /work. Follows /feature.
version: 3.0.0
languages: all
---

# /work — execute the tickets

A human-driven loop; no gate between tickets. Shared rules:
`~/.claude/skills/dev-workflow/workflow.md`. `W=~/.claude/skills/dev-workflow/scripts/workflow-state.sh`

**Why primitives, not `subagent-driven-development`:** SDD finishes/merges the
branch when its plan completes; handed one ticket it trips the merge gate after
ticket 1. `/work` drives the primitives and leaves finishing to `/ship`.

## Steps

1. Ensure you're on the feature branch with a clean tree.

2. **Pick the next ticket** — `bash $W tickets` shows each ticket + status. The
   frontier ticket is one whose `Blocked by` are all `done`. Mark its
   `**Status:** in-progress`.

3. **Execute (primitives)** — capture `BASE=$(git rev-parse HEAD)`; dispatch a
   fresh implementer subagent (crafted context) to build just this ticket via
   `superpowers:test-driven-development` (no code without a failing test); on
   breakage `superpowers:systematic-debugging`. Commit the work. Do NOT invoke
   SDD; do NOT finish the branch.

4. **Independent review over `BASE..HEAD`** — the Superpowers task reviewer
   (Claude) + `reviewers:codex --base <BASE>` (cross-model), dispatched together;
   append `~/.claude/skills/dev-workflow/smell-baseline.md` (Fowler lens) to the
   Claude reviewer's brief.

5. **Close only when done** — after both reviews return, findings are resolved
   (re-review after fixes), and `superpowers:verification-before-completion`
   passes: mark `**Status:** done`. Otherwise leave `in-progress`, or `blocked`
   with a reason. If a finding changes the approved scope, stop and re-run
   `/feature`'s ticket gate.

6. **Loop** — repeat until `bash $W tickets` shows `N/N done`, then hand off to
   `/ship`. Don't pause between tickets.
