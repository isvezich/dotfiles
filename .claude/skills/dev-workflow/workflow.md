<!-- ABOUTME: Single source of truth for the triage/feature/work/ship workflow. -->
<!-- ABOUTME: The four router skills point here so the shared rules live in one place. -->

# Dev Workflow — shared reference

A four-verb development loop that combines the Superpowers process spine with
Matt Pocock's design/understanding skills, wired to keep the coordinator
context lean. The router skills (`triage`, `feature`, `work`, `ship`) are thin —
they invoke the tuned upstream skills in order and stop at the human gates
defined here. **Do not reimplement upstream skill content in the routers.**

## Iron rule: local tracking only

All triage, specs, and tickets are **local files in the project repo** — never
GitHub Issues, Jira, Linear, or any remote tracker. This overrides the upstream
Matt Pocock skills' default of publishing to an issue tracker, and their
`.scratch/` local fallback path. The canonical local layout is:

| Artifact | Location | Written by |
|----------|----------|------------|
| Domain glossary | `CONTEXT.md` | `domain-modeling` (via `grill-with-docs`) |
| Architecture decisions | `docs/decisions/` (ADRs) | `domain-modeling` |
| Specs | `docs/specs/<slug>.md` | `to-spec` |
| Tickets | `tickets/<NN>-<slug>.md` | `to-tickets` (local template) |
| Durable state (the ledger) | `.ai/workflow.yaml` | `workflow-state.sh` + the agent |

When an upstream skill says "publish to the issue tracker" or "apply the
`ready-for-agent` label", translate that to: write the local file above and set
its `**Status:**` line. When it offers a tracker-vs-local choice, always choose
local and use these paths (not `.scratch/`).

## The command surface (4 human gates)

```
/triage   → decide what to build        ↯ maintainer picks state (skip if no inbound queue)
/feature  → design + break down work     ↯ approve spec, then ↯ approve tickets
/work     → execute all tickets          (autonomous loop — NO gate between tickets)
/ship     → verify + integrate           ↯ choose merge / PR / keep
```

Gates sit at **decisions**, never inside the `/work` loop — Superpowers
subagent-driven-development runs tickets continuously without check-ins.

## The keystone: `.ai/workflow.yaml`

This file is the recovery map. Every durable fact about the in-flight feature
(slug, spec path, branch, status, current ticket, hand-off notes) lives here,
not in the conversation. That is what makes per-ticket fresh contexts safe:
losing the conversation costs nothing because the ledger + `git log` + the
ticket files reconstruct the state. **After compaction, trust this file over
your own recollection.** Scaffold and read it with:

```bash
bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh init      # create local layout + starter state
bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh show      # print current state
bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh tickets   # list tickets + done/total
```

The script scaffolds and reads; the agent owns the *contents* of
`.ai/workflow.yaml` (edit it directly to record progress).

## Ticket status vocabulary

Ticket `**Status:**` lines use: `ready-for-agent`, `in-progress`, `done`,
`blocked`. `workflow-state.sh tickets` counts `done` against the total.

## Context-rot discipline (why this exists)

- **Delegate, don't inline.** Reading a large codebase, running a review, or
  doing research happens in a subagent whose context is thrown away — only the
  conclusion returns to the coordinator. (Superpowers: subagents "should never
  inherit your session's context"; Matt: `research`/`code-review` run in
  isolated agents "so they don't pollute each other's context".)
- **Externalize state to files.** The ledger, specs, ADRs, and tickets are the
  durable record; the conversation is disposable.
- **One vertical slice per fresh context.** `to-tickets` sizes each ticket to
  fit a single fresh context window; `/work` executes one at a time.
- **Prune sediment.** Delete stale notes from `.ai/workflow.yaml` as they go
  cold — adding feels safe and removing feels risky, so rot accumulates unless
  you actively prune.

## Superpowers auto-trigger caveat

Superpowers' `brainstorming` auto-fires (via its SessionStart hook) on "let's
build X". That is fine — `/feature` uses it as its first step. But do not let
Superpowers' own downstream flow and these routers both drive; once a `/`-verb
is invoked, follow that router and treat it as authoritative for the phase.
