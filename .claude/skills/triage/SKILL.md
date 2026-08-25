---
name: triage
disable-model-invocation: true
description: Decide what to build from an inbound request, working a LOCAL flat ticket tracker only (never GitHub/Jira). Inlines Matt Pocock's triage logic (his triage skill is user-only). A human-driven checklist. Invoke explicitly as the first gate; skip for solo idea-driven work (go straight to /feature).
when_to_use: When there is an inbound queue of requests/bugs to evaluate before committing to build. The user runs /triage. Skip for solo idea-driven work.
version: 3.0.0
languages: all
---

# /triage — decide what to build

A human-driven checklist over the local **intake** dir `requests/` (never
GitHub/Jira). Execution tickets live elsewhere (`tickets/<feature-slug>/`, owned
by `/feature`) so a deferred/rejected request never blocks a feature's count.
Shared rules: `~/.claude/skills/dev-workflow/workflow.md`.

## Steps

1. `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh init` if the
   tracker doesn't exist yet.

2. **Triage the request (inline — Matt's `triage` is user-only):**
   - Category: bug | enhancement.
   - Redundancy / prior-rejection: search the codebase by domain concept, read
     `docs/decisions/` ADRs; if already implemented → `wontfix`.
   - Verify the claim where you can (reproduce a bug).
   - Decide an intake status: `needs-info` | `ready-for-human` | `wontfix` (or
     *adopt* — see step 4). Synthesize your own summary; don't forward the
     inbound text verbatim.
   - If it needs shaping, invoke `mattpocock-skills:grilling` +
     `mattpocock-skills:domain-modeling`, or hand to `/feature`.

3. **HUMAN GATE ↯** — present your category + status recommendation; the
   maintainer directs. Record the outcome as `requests/<id>.md` with a
   `**Status:**` line.

4. **Adopt for build** → hand off to `/feature` (which creates
   `tickets/<feature-slug>/`). Mark the `requests/<id>.md` `**Status:**
   ready-for-human` with a pointer to the feature slug, so the intake record is
   closed out rather than left dangling.
