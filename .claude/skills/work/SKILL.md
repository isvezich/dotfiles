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
   shows each ticket + status. A ticket is frontier-ready only if every id in its
   `Blocked by` resolves to a ticket in the **same** feature dir and is `done`;
   an unknown id or a dependency cycle → STOP and report for human correction
   (fail closed, don't guess). **If no frontier exists — every remaining ticket
   is `blocked`, or the list is empty — STOP and report; do not loop on an
   impossible queue.**
   Otherwise mark the chosen ticket `**Status:** in-progress` and **commit that
   status change** so the implementer starts from a clean tree.

3. **Execute (primitives)** — note this ticket's review base: run
   `git rev-parse HEAD` and **keep the printed sha as `BASE` in your working
   context** (a shell variable won't survive to the next Bash call — substitute
   the literal sha later). Dispatch a fresh implementer subagent (crafted
   context, never this session's history) to build just this ticket via
   `superpowers:test-driven-development` (no production code without a failing
   test); on breakage `superpowers:systematic-debugging` (root cause, not a
   patch). Commit the work. Do NOT invoke SDD; do NOT finish the branch.

4. **Independent review over `BASE..HEAD`** — first ensure the implementer's work
   is committed and `git status --porcelain` is empty, so both reviewers assess
   the same committed range and the codex sentinel matches `HEAD`. Then dispatch
   `superpowers:requesting-code-review` (the public interface — Claude) **and**
   `reviewers:codex --base <BASE>` (cross-model, the literal sha from step 3)
   together in one message. Give the Claude reviewer's brief the approved ticket
   with its acceptance criteria, the relevant spec sections, and
   `~/.claude/skills/dev-workflow/smell-baseline.md` (Fowler lens) — so it checks
   spec/ticket compliance, not just diff defects; codex is the independent
   defect-finding pass. A review only counts if **both** reviewers complete and
   return a verdict over that range — a plugin/network/timeout failure blocks
   progression, it is not "no findings." This is per-ticket fast feedback; the
   whole-feature review runs in `/ship`.

5. **Close only when done** — after both reviews return, every blocking finding
   is resolved, the ticket's **acceptance checkboxes are actually satisfied** (not
   just its status string), and `superpowers:verification-before-completion`
   passes: set `**Status:** done` and **commit that status change** so the
   terminal state lives on the branch, not just the working tree. **Re-review
   after any fix:** commit the fix and confirm a clean tree first, then re-run
   both reviewers over `BASE..HEAD` (an uncommitted fix is invisible to
   `reviewers:codex --base` and the sentinel). Otherwise leave `in-progress`, or
   set `blocked` with a reason (also committed). If a finding changes the approved
   **scope**, stop and re-run `/feature` from the **spec gate** (step 5): update
   and re-approve the spec, then for every ticket the change touches — including
   ones already `done` — reset `**Status:** ready-for-agent`, regenerate and
   re-approve its acceptance criteria, and re-run it through `/work`, so nothing
   ships validated against the superseded scope.

6. **Loop** — repeat from step 2 until
   `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets <feature-slug>`
   reports `N/N done`, then hand off to `/ship`. Don't pause between tickets.
