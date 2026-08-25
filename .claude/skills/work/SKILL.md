---
name: work
disable-model-invocation: true
description: Execute one feature's approved tickets via Superpowers primitives per ticket (fresh implementer + TDD + a Claude review via requesting-code-review + cross-model Codex review + verification) — NOT subagent-driven-development, which would finish the branch after ticket 1. Fowler smell baseline as an extra review lens. Autonomous between tickets; the whole-feature review and finishing are /ship's job. A human-driven checklist. Invoke explicitly as /work.
when_to_use: When a feature has an approved spec and local tickets and you're ready to implement. The user runs /work. Follows /feature.
version: 3.1.0
languages: all
---

# /work — execute the tickets

A human-driven loop; no gate between tickets. Shared rules:
`~/.claude/skills/dev-workflow/workflow.md`.
Helper: `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh` — call it
by this full path (separate Bash calls don't share shell variables, so a `W=...`
alias would expand to nothing).

**Why primitives, not `subagent-driven-development`:** SDD finishes/merges the
branch when its plan completes; handed one ticket it trips the merge gate after
ticket 1. `/work` drives the primitives and leaves finishing to `/ship`.

## Steps

1. **Clean start** — on the feature branch with `git status --porcelain` empty.
   Know the feature slug (the `tickets/<feature-slug>/` dir from `/feature`).

2. **Pick the next ticket** —
   `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets <feature-slug>`
   shows each ticket + status. The frontier ticket is one whose `Blocked by` are
   all `done`. **If no such frontier exists — every remaining ticket is `blocked`,
   or the list is empty — STOP and report; do not loop on an impossible queue.**
   Otherwise mark the chosen ticket `**Status:** in-progress` and **commit that
   status change** so the implementer starts from a clean tree.

3. **Execute (primitives)** — capture `BASE=$(git rev-parse HEAD)`; dispatch a
   fresh implementer subagent (crafted context, never this session's history) to
   build just this ticket via `superpowers:test-driven-development` (no
   production code without a failing test); on breakage
   `superpowers:systematic-debugging` (root cause, not a patch). Commit the work.
   Do NOT invoke SDD; do NOT finish the branch.

4. **Independent review over `BASE..HEAD`** — `superpowers:requesting-code-review`
   (the public interface — Claude) **and** `reviewers:codex --base <BASE>`
   (cross-model), dispatched together in one message; append
   `~/.claude/skills/dev-workflow/smell-baseline.md` (Fowler lens) to the Claude
   reviewer's brief. This is per-ticket fast feedback; the whole-feature review
   runs in `/ship`.

5. **Close only when done** — after both reviews return, every blocking finding
   is resolved (re-review after fixes), and
   `superpowers:verification-before-completion` passes: set `**Status:** done`
   and **commit that status change** so the terminal state lives on the branch,
   not just the working tree. Otherwise leave `in-progress`, or set `blocked`
   with a reason (also committed). If a finding changes the approved scope, stop
   and re-run `/feature`'s ticket gate.

6. **Loop** — repeat from step 2 until
   `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets <feature-slug>`
   reports `N/N done`, then hand off to `/ship`. Don't pause between tickets.
