---
name: feature
disable-model-invocation: true
description: Start an approved feature — design it, pin the domain language, write a local spec, and break it into local tickets. Router chaining Superpowers brainstorming + Matt Pocock grilling/domain-modeling (model-invocable), then inlined local spec + tickets (Matt's to-spec/to-tickets are user-only so a router can't invoke them). Writes LOCAL files only (docs/specs, docs/decisions, tickets). Two human gates. Invoke explicitly as /feature.
when_to_use: When starting a new, approved piece of work and you need a design, spec, and ticket breakdown before implementation. The user runs /feature. Follows /triage, or is itself the intake for solo idea-driven work.
version: 1.0.0
languages: all
---

# /feature — design and break down work (local artifacts)

Router. Shared rules and the local layout are in
`~/.claude/skills/dev-workflow/workflow.md` — read it first if you have not this
session, then run these steps in order.

**Invocability:** a router (itself user-invoked) can only invoke *model-invocable*
skills. `grilling`, `domain-modeling`, `research`, `prototype`, `codebase-design`
are invocable — invoke those. Matt's `grill-with-docs`, `to-spec`, and
`to-tickets` are `disable-model-invocation: true` (a router's `Skill` call to them
is rejected), so their steps are **inlined** below. Inlining loses nothing here:
`to-spec`/`to-tickets` do no interview (they only synthesize), and we already
override their publish step to local files.

## Steps

1. **Scaffold state** (idempotent):
   ```bash
   bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh init
   ```
   Set `.ai/workflow.yaml` `status: designing` and the feature slug.

2. **Frame + classify** — invoke `superpowers:brainstorming`. Let it classify
   the work (spike / bounded / architectural) and hold its HARD-GATE (no
   implementation without approval). This is also what absorbs the Superpowers
   auto-trigger so it does not run a competing flow.

3. **Grill into shape + capture docs** — invoke `mattpocock-skills:grilling` and
   `mattpocock-skills:domain-modeling` (both model-invocable — this replaces the
   user-only `grill-with-docs` wrapper). Sharpen the design a round at a time;
   land domain terms in `CONTEXT.md` and hard-to-reverse decisions as ADRs in
   `docs/decisions/`.

4. **De-risk as needed** (only when a fact or design is genuinely uncertain):
   - `mattpocock-skills:research` — dispatch a background agent for
     primary-source facts; it returns a cited Markdown file, keeping the reading
     out of your context.
   - `mattpocock-skills:prototype` — throwaway spike for a risky state model or
     UI question.
   - `mattpocock-skills:codebase-design` — the seam/depth vocabulary for the
     next step.

5. **Write the spec (local, inlined)** — `to-spec` is user-only, and it does no
   interview — it just synthesizes what's already been discussed. So synthesize
   it here and write `docs/specs/<slug>.md` with: Problem Statement, Solution,
   User Stories, Implementation Decisions (**including the test seams** — prefer
   existing seams, the highest seam possible, fewest new seams), Testing
   Decisions, Out of Scope. No re-interview. NOT a tracker, NOT `.scratch/`.
   **HUMAN GATE ↯ — get the spec approved before breaking it into tickets.**

6. **Break into tickets (local, inlined)** — `to-tickets` is user-only; break the
   spec into **tracer-bullet vertical slices** yourself, one file per ticket at
   `tickets/<NN>-<slug>.md` in dependency order (blockers first). Each file:
   `**What to build:**`, `**Blocked by:**` (the ticket numbers that gate it, or
   "None"), `**Status:** ready-for-agent`, and acceptance-criteria checkboxes.
   Size each slice to fit a single fresh context window. NOT a tracker, NOT
   `.scratch/`.
   **HUMAN GATE ↯ — get the ticket breakdown approved.**

7. **Update state** — record spec path and ticket list in `.ai/workflow.yaml`;
   leave `status: designing` until `/work` begins.

Hand off to `/work` once tickets are approved.
