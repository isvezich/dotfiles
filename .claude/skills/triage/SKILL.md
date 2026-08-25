---
name: triage
disable-model-invocation: true
description: Decide what to build from an inbound request, working a LOCAL flat ticket tracker only (never GitHub/Jira). Inlines Matt Pocock's triage logic (his triage skill is user-only). A human-driven checklist. Invoke explicitly as the first gate; skip for solo idea-driven work (go straight to /feature).
when_to_use: When there is an inbound queue of requests/bugs to evaluate before committing to build. The user runs /triage. Skip for solo idea-driven work.
version: 3.0.0
languages: all
---

# /triage — decide what to build

A human-driven checklist over the flat local `tickets/` (never GitHub/Jira).
Shared rules: `~/.claude/skills/dev-workflow/workflow.md`.

## Steps

1. `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh init` if the
   tracker doesn't exist yet.

2. **Triage the request (inline — Matt's `triage` is user-only):**
   - Category: bug | enhancement.
   - Redundancy / prior-rejection: search the codebase by domain concept, read
     `docs/decisions/` ADRs; if already implemented → `wontfix`.
   - Verify the claim where you can (reproduce a bug).
   - Decide a status for the ticket: `ready-for-agent` | `needs-info` |
     `ready-for-human` | `wontfix`.
   - If it needs shaping, invoke `mattpocock-skills:grilling` +
     `mattpocock-skills:domain-modeling`, or hand to `/feature`.

3. **HUMAN GATE ↯** — present your category + status recommendation; the
   maintainer directs. Record the outcome as a `tickets/<id>.md` with a
   `**Status:**` line.

Adopting an item for build → hand off to `/feature`.
