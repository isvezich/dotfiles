---
name: work
disable-model-invocation: true
description: Execute the approved tickets in an isolated worktree via Superpowers subagent-driven development (fresh agent + TDD + review + verification per ticket), with a parallel Matt Pocock two-axis code review. Runs the tickets autonomously — no human gate between them. Updates the durable ledger after each. Invoke explicitly as /work.
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

4. **Two-axis review** — invoke `mattpocock-skills:code-review` (Standards ‖
   Spec) on the ticket's diff, in parallel with the Superpowers task review.
   Per the user's CLAUDE.md, also fire `codex-review` alongside any Superpowers
   review. Dispatch reviews in one message so they run concurrently.

5. **Close the ticket** — set the ticket's `**Status:** done`, clear
   `current_ticket`, and prune any now-stale notes from `.ai/workflow.yaml`.

6. **Loop** — return to step 2 until `workflow-state.sh tickets` reports
   `N/N done`. Do not pause to check in between tickets.

When all tickets are `done`, hand off to `/ship`.
