---
name: work
disable-model-invocation: true
description: Execute the approved tickets in an isolated worktree via Superpowers subagent-driven development (fresh agent + TDD + review + verification per ticket), with a parallel cross-model Codex review (reviewers:codex) and the Fowler smell baseline as an extra lens. Runs the tickets autonomously — no human gate between them. Updates the durable ledger after each. Invoke explicitly as /work.
when_to_use: When a feature has an approved spec and local tickets and you are ready to implement. The user runs /work. Follows /feature.
version: 1.0.0
languages: all
---

# /work — execute the tickets (autonomous loop)

Thin router. Shared rules are in `~/.claude/skills/dev-workflow/workflow.md`.
This is the one phase with **no human gate between units of work** — Superpowers
subagent-driven-development executes continuously. Stop only for the four
Superpowers stop conditions (irreversible/destructive op, security-sensitive
action, out-of-worktree side effect, or a plan so broken every path is a guess).

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

3. **Execute the ticket** — invoke `superpowers:subagent-driven-development` for
   this ticket: a fresh implementer subagent (never inheriting this session's
   history), TDD inner loop (`superpowers:test-driven-development` — no
   production code without a failing test), task review, and
   `superpowers:verification-before-completion`. If anything breaks, the fresh
   agent uses `superpowers:systematic-debugging` (root cause before fix) —
   escalate to architecture review after 3+ failed fixes.

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

5. **Close the ticket** — set the ticket's `**Status:** done`, clear
   `current_ticket`, and prune any now-stale notes from `.ai/workflow.yaml`.

6. **Loop** — return to step 2 until `workflow-state.sh tickets` reports
   `N/N done`. Do not pause to check in between tickets.

When all tickets are `done`, hand off to `/ship`.
