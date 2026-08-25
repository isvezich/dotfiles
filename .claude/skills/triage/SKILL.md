---
name: triage
disable-model-invocation: true
description: Decide what to build from an inbound request, working a LOCAL ticket tracker only (never GitHub/Jira). Inlines Matt Pocock's triage state machine (his triage skill is user-only, so a router can't invoke it) and uses model-invocable grilling/domain-modeling when a request needs shaping. Invoke explicitly as the first gate; skip when work starts from your own idea (go straight to /feature).
when_to_use: When there is an inbound queue of requests/bugs to evaluate before committing to build. The user runs /triage. Skip for solo idea-driven work — /feature's grilling is the intake there.
version: 1.0.0
languages: all
---

# /triage — decide what to build (local tracker)

Thin router. See `~/.claude/skills/dev-workflow/workflow.md` for the shared
rules; the iron rule (local files only) and the local layout live there.

## Steps

1. **Read the shared reference** at `~/.claude/skills/dev-workflow/workflow.md`
   if you have not this session.

2. **Ensure the local tracker exists:**
   ```bash
   bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh init
   ```

3. **Triage the request (inlined)** — Matt's `triage` skill is user-only, so run
   its state machine here against the LOCAL `tickets/` (never GitHub/Jira):
   - **Category:** `bug` | `enhancement`.
   - **Redundancy / prior-rejection:** search the codebase by domain concept and
     read `docs/decisions/` ADRs; if already implemented → `wontfix`.
   - **Verify the claim** where you can (reproduce a bug from its steps).
   - **State** (record on the ticket's `**Status:**` line):
     `ready-for-agent` | `needs-info` | `ready-for-human` | `wontfix` |
     `needs-triage`. ("Needs attention" = any ticket whose status is not `done`
     / `wontfix` — `workflow-state.sh tickets` lists them.)
   - If the request needs fleshing out, invoke `mattpocock-skills:grilling` +
     `mattpocock-skills:domain-modeling` (both model-invocable), or hand off to
     `/feature` (its grilling is the intake) rather than duplicating it here.

4. **HUMAN GATE ↯** — present your category + state recommendation and wait for
   the maintainer to direct. Apply the outcome as a local ticket + status.

Record the decision in `.ai/workflow.yaml` (`status: triaging`, and the chosen
next feature) so the next session can pick up.
