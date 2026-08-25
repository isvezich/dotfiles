---
name: work
disable-model-invocation: true
description: Execute the approved tickets on an isolated branch via Superpowers primitives per ticket (fresh implementer subagent + TDD + a Claude review + cross-model Codex review + verification) — NOT subagent-driven-development, which would finish/merge the branch after the first ticket. Fowler smell baseline as an extra review lens. Runs the tickets autonomously — no human gate between them; finishing is /ship's job. Updates the durable ledger after each. Invoke explicitly as /work.
when_to_use: When a feature has an approved spec and local tickets and you are ready to implement. The user runs /work. Follows /feature.
version: 1.0.0
languages: all
---

# /work — execute the tickets (autonomous loop)

Thin router. Shared rules are in `~/.claude/skills/dev-workflow/workflow.md`.
This is the one phase with **no human gate between units of work** — it executes
continuously. Stop only for the four Superpowers stop conditions
(irreversible/destructive op, security-sensitive action, out-of-worktree side
effect, or a plan so broken every path is a guess).

**Why primitives, not `subagent-driven-development`:** SDD takes the *whole plan*
and, when that plan completes, runs a final whole-branch review and invokes
`finishing-a-development-branch`. Handed a single ticket it would treat that
ticket as the whole plan and trip the merge/PR/keep gate after ticket 1 (and
`/ship` would then double-finish). So `/work` drives the primitives per ticket
and leaves finishing to `/ship`.

## Steps

1. **Isolate the workspace** — invoke `superpowers:using-git-worktrees` to
   create/verify an isolated worktree and a clean test baseline. Record the
   branch in `.ai/workflow.yaml`; set `status: working`.

2. **Pick the next ticket** — the frontier ticket whose "Blocked by" edges are
   all `done`:
   ```bash
   bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets
   ```
   Read the ticket file for its blockers. Set its `**Status:** in-progress` and
   `current_ticket` in the ledger.

3. **Execute the ticket (primitives, not SDD)** — dispatch a fresh implementer
   subagent (crafted context, never this session's history) to build just this
   ticket following `superpowers:test-driven-development` (no production code
   without a failing test); on breakage it uses `superpowers:systematic-debugging`
   (root cause before fix) — escalate to architecture review after 3+ failed
   fixes. Do **not** invoke `superpowers:subagent-driven-development` and do
   **not** finish the branch here (see the note above — that's `/ship`).

4. **Independent review — two models, one Claude pass** — the Superpowers task
   review (Claude) runs on the ticket's diff; per the user's CLAUDE.md, fire
   `reviewers:codex` (GPT-5.5) alongside it for a cross-model second opinion.
   Dispatch both in one message so they run concurrently. Only one Claude-side
   review by design: the Superpowers reviewer is the more rigorous rubric — it
   treats the implementer's report as unverified, cross-checks named risks
   outside the diff (lock ordering, API contracts, shared state), and covers
   tests/security/architecture/production-readiness. A second same-model review
   would mostly correlate; the extra bug-catching comes from the Codex model.
   Extra lens: append `~/.claude/skills/dev-workflow/smell-baseline.md` (the
   Fowler code-smell baseline, grafted from mattpocock's review) to the task
   reviewer's brief so the one Claude pass also matches the diff against those
   12 design smells.

5. **Close the ticket (only when actually done)** — close ONLY after: both
   reviews have returned, every blocking finding is resolved (re-review after
   any fix), and `superpowers:verification-before-completion` passes on the
   ticket's diff. Then set `**Status:** done`, clear `current_ticket`, prune
   stale notes. If a review failed/timed out or findings are unresolved, leave
   `**Status:** in-progress` or set `blocked` with a reason — do not close.

6. **Loop** — return to step 2 until `workflow-state.sh tickets` reports
   `N/N done`. Do not pause to check in between tickets.

When all tickets are `done`, hand off to `/ship`.
