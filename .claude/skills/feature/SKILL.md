---
name: feature
description: Start an approved feature — design it, pin the domain language, write a local spec, and break it into local tickets. Thin router chaining Superpowers brainstorming + Matt Pocock grill-with-docs/to-spec/to-tickets, all writing LOCAL files only (docs/specs, docs/decisions, tickets). Two human gates. Invoke explicitly as /feature.
when_to_use: When starting a new, approved piece of work and you need a design, spec, and ticket breakdown before implementation. The user runs /feature. Follows /triage, or is itself the intake for solo idea-driven work.
version: 1.0.0
languages: all
---

# /feature — design and break down work (local artifacts)

Thin router. Shared rules and the local layout are in
`~/.claude/skills/dev-workflow/workflow.md` — read it first if you have not this
session, then run these steps in order. Do not reimplement the upstream skills;
invoke them.

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

3. **Grill into shape + capture docs** — invoke `mattpocock-skills:grill-with-docs`
   (which runs `grilling` + `domain-modeling`). Sharpen the design a round at a
   time; land domain terms in `CONTEXT.md` and hard-to-reverse decisions as ADRs
   in `docs/decisions/`.

4. **De-risk as needed** (only when a fact or design is genuinely uncertain):
   - `mattpocock-skills:research` — dispatch a background agent for
     primary-source facts; it returns a cited Markdown file, keeping the reading
     out of your context.
   - `mattpocock-skills:prototype` — throwaway spike for a risky state model or
     UI question.
   - `mattpocock-skills:codebase-design` — the seam/depth vocabulary for the
     next step.

5. **Write the spec (local)** — invoke `mattpocock-skills:to-spec`. Override its
   publish step: write to `docs/specs/<slug>.md` (NOT a tracker, NOT `.scratch/`).
   It synthesizes the conversation — no re-interview — and sketches the test
   seams.
   **HUMAN GATE ↯ — get the spec approved before breaking it into tickets.**

6. **Break into tickets (local)** — invoke `mattpocock-skills:to-tickets`.
   Override: use the local per-ticket template, one file per ticket at
   `tickets/<NN>-<slug>.md` in dependency order (blockers first), each with a
   `**Status:** ready-for-agent` line and its "Blocked by" edges. NOT a tracker,
   NOT `.scratch/`.
   **HUMAN GATE ↯ — get the ticket breakdown approved.**

7. **Update state** — record spec path and ticket list in `.ai/workflow.yaml`;
   leave `status: designing` until `/work` begins.

Hand off to `/work` once tickets are approved.
