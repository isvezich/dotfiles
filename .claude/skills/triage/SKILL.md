---
name: triage
description: Decide what to build from an inbound request, working a LOCAL ticket tracker only (never GitHub/Jira). Thin router over mattpocock-skills:triage with local-file enforcement. Invoke explicitly as the first gate; skip when work starts from your own idea (go straight to /feature).
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

3. **Run the upstream triage skill** — invoke `mattpocock-skills:triage` — with
   these overrides:
   - The "issue tracker" is the local `tickets/` directory. Never GitHub
     Issues, Jira, or any remote tracker.
   - A ticket is a file `tickets/<NN>-<slug>.md`; its state is the
     `**Status:**` line (`ready-for-agent` | `in-progress` | `done` |
     `blocked`), not a tracker label.
   - "Show what needs attention" = list `tickets/` files whose status is not
     `done` (use `workflow-state.sh tickets`), plus any raw request the user
     brings.
   - Its redundancy / prior-rejection checks still apply: search the codebase
     by domain concept, and read any `docs/decisions/` ADRs and out-of-scope
     notes before recommending.
   - If the request needs fleshing out, it will pull in grilling +
     domain-modeling — that is exactly `/feature`'s job, so hand off to
     `/feature` rather than duplicating the interview here.

4. **HUMAN GATE ↯** — present your category + state recommendation and wait for
   the maintainer to direct. Apply the outcome as a local ticket + status.

Record the decision in `.ai/workflow.yaml` (`status: triaging`, and the chosen
next feature) so the next session can pick up.
