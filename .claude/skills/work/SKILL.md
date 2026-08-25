---
name: work
disable-model-invocation: true
description: Execute the approved feature's tickets — refusing unapproved or drifted work (check-ready), scoped to that one feature, via Superpowers primitives per ticket (fresh implementer + TDD + a Claude review + cross-model Codex over the pinned BASE..HEAD range + verification), NOT branch-finishing SDD. Terminates (not spins) on blocked/no-frontier. Autonomous between tickets within the approved envelope. Invoke explicitly as /work.
when_to_use: When a feature is ready-to-work (spec + tickets approved). The user runs /work. Follows /feature.
version: 2.0.0
languages: all
---

# /work — execute the tickets (v2, approval-guarded)

Router. Shared rules + the v2 state model are in
`~/.claude/skills/dev-workflow/workflow.md`. `W=~/.claude/skills/dev-workflow/scripts/workflow-state.sh`

**Why primitives, not `subagent-driven-development`:** SDD finishes/merges the
branch when its plan completes; handed one ticket it would trip the merge gate
after ticket 1. `/work` drives the primitives and leaves finishing to `/ship`.

## Steps

1. **Refuse unless approved + un-drifted** — `bash $W check-ready`. On non-zero
   (not `ready-to-work`, HEAD doesn't descend from the approved `tickets_commit`,
   or a ticket digest drifted) STOP and surface the message — do not implement
   unapproved/changed work. Ensure you're on the feature's worktree/branch. Then
   `bash $W set-status working`. **Restarting** interrupted work instead? Use
   `bash $W resume` (revalidates the immutable bundle + branch and returns to
   `working` from `working`/`blocked`/`parked`) — `check-ready` only accepts a
   fresh `ready-to-work`.

2. **Pick the next ticket — active feature only** — `bash $W tickets --feature
   <slug>` (from the ledger manifest; never the inbox or another feature; the
   closed bundle means no ticket outside the manifest is eligible). The frontier
   ticket is one whose `Blocked by` are all `done`.
   `bash $W set-ticket <path> in-progress; bash $W set current_ticket <path>`
   (status is written to the ledger map, NOT the committed ticket file).

3. **Execute (primitives)** — capture `BASE=$(git rev-parse HEAD)` first; dispatch
   a fresh implementer subagent (crafted context) to build just this ticket via
   `superpowers:test-driven-development` (no code without a failing test); on
   breakage `superpowers:systematic-debugging`. Commit the ticket's work. Do NOT
   invoke SDD; do NOT finish the branch.

4. **Independent review over the pinned range** — review exactly `BASE..HEAD`:
   the Superpowers task reviewer (Claude) + `reviewers:codex --base <BASE>`
   (cross-model), dispatched together; append `~/.claude/skills/dev-workflow/smell-baseline.md`
   (Fowler lens) to the Claude reviewer's brief.

5. **Close only when done** — after both reviews return, all blocking findings
   are resolved (re-review after fixes), and `superpowers:verification-before-completion`
   passes: `bash $W set-ticket <path> done; bash $W set current_ticket null`.
   Otherwise leave it `in-progress`, or `bash $W set-ticket <path> blocked`.

6. **Renewed gate** — if resolving a finding would change the approved envelope
   (problem/spec/acceptance/deps/out-of-scope), STOP: `bash $W set-status
   designing` (legal from `working`/`blocked`), edit + re-commit the spec/tickets,
   re-run the `/feature` gates (`approve-spec`/`approve-tickets`) to re-pin, then
   `resume`. "No gate between tickets" applies only *within* the approved envelope.

7. **Terminate, don't spin** — if a ticket is blocked, there's no executable
   frontier, `graph-validate` reports a cycle, or a review times out:
   `bash $W set-ticket <path> blocked; bash $W set-status blocked`, record a
   durable reason + handoff, and stop.

8. **Loop** — repeat step 2 until `tickets --feature <slug>` is `N/N done`, then
   hand off to `/ship`. Do not pause between tickets within the envelope.
