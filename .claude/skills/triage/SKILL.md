---
name: triage
disable-model-invocation: true
description: Decide what to build from an inbound request, working a LOCAL inbox queue only (never GitHub/Jira). Inlines Matt Pocock's triage state machine (his triage skill is user-only) and uses model-invocable grilling/domain-modeling when a request needs shaping. Separate from feature execution. Invoke explicitly as the first gate; skip for solo idea-driven work (go straight to /feature).
when_to_use: When there is an inbound queue of requests/bugs to evaluate before committing to build. The user runs /triage. Skip for solo idea-driven work.
version: 2.0.0
languages: all
---

# /triage — decide what to build (v2, local inbox)

Router. Shared rules + the v2 state model are in
`~/.claude/skills/dev-workflow/workflow.md`.

`W=~/.claude/skills/dev-workflow/scripts/workflow-state.sh`

## Steps

1. **Ensure the tracker exists:** `bash $W init` (creates `tickets/inbox/` +
   `tickets/features/`). `bash $W set-status triaging`.

2. **Triage the request (inlined — Matt's `triage` is user-only)** against the
   LOCAL `tickets/inbox/` (never GitHub/Jira):
   - Intake items are `tickets/inbox/<id>.md`.
   - **Category:** bug | enhancement.
   - **Redundancy / prior-rejection:** search the codebase by domain concept and
     read `docs/decisions/` ADRs; if already implemented → `wontfix`.
   - **Verify** the claim where you can (reproduce a bug).
   - **State** (the item's `**Status:**` line): `needs-triage` | `needs-info` |
     `ready-for-human` | `wontfix` | `ready-for-feature`.
   - If it needs shaping, invoke `mattpocock-skills:grilling` +
     `mattpocock-skills:domain-modeling` (model-invocable).

   Inbox items **never** count toward a feature's completion — `/work` and
   `/ship` operate only on `tickets/features/<slug>/`.

3. **HUMAN GATE ↯** — present your category + state recommendation; the
   maintainer directs. Apply the outcome to the inbox item.

4. **Adopt → build.** When an item becomes `ready-for-feature`, hand off to
   `/feature` (it creates the branch+worktree and the feature's ticket dir). Then
   `bash $W set-status idle` if no feature is being started now, or let `/feature`
   drive from here.
