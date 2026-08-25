---
name: feature
disable-model-invocation: true
description: Start an approved feature — design it (grilling/domain-modeling), then write a local spec and break it into local per-feature tickets. A human-driven checklist over a local tracker (no state machine). Two human gates. Invoke explicitly as /feature.
when_to_use: When starting a new, approved piece of work and you need a design, spec, and ticket breakdown before implementation. The user runs /feature. Follows /triage, or is the intake for solo idea-driven work.
version: 3.0.0
languages: all
---

# /feature — design and break down work

A human-driven checklist. Shared rules are in
`~/.claude/skills/dev-workflow/workflow.md`. This is deliberately NOT a state
machine — you drive it; the local tracker just holds artifacts.

**Invocability:** a router can only invoke *model-invocable* skills — `grilling`,
`domain-modeling`, `research`, `prototype`, `codebase-design`. Matt's
`grill-with-docs`/`to-spec`/`to-tickets` are user-only, so their (interview-free)
logic is inlined below.

## Steps

1. **Scaffold + branch:** `bash ~/.claude/skills/dev-workflow/scripts/workflow-state.sh init`
   (creates `docs/specs/`, `docs/decisions/`, `tickets/`, `requests/`). Pick one
   canonical `<slug>` for this feature — the spec is `docs/specs/<slug>.md` and the
   tickets live in `tickets/<slug>/` (same value; keep them equal). **Record the
   fork-point (`<feature-base>`):** capture `git rev-parse HEAD` on the target
   branch *before* creating the feature branch; if you're resuming an existing
   branch, derive it with `git merge-base <target-branch> HEAD` (not `HEAD`, which
   is the tip). You'll write it into the spec in step 5; `/work`+`/ship` review
   against it. Then create/switch to the feature branch. One feature per branch.

2. **Classify + frame** (inline): spike / bounded / architectural — say which,
   and don't implement before the gates below. (Consult `superpowers:brainstorming`'s
   rubric if useful, but keep control here rather than handing off to its full flow.)

3. **Grill + capture docs:** invoke `mattpocock-skills:grilling` and
   `mattpocock-skills:domain-modeling`. Land domain terms in `CONTEXT.md`,
   hard-to-reverse decisions as ADRs in `docs/decisions/`.

4. **De-risk as needed:** `research`, `prototype`, `codebase-design`. **Override
   `prototype`'s completion rule:** it's a throwaway spike only — capture the
   validated decision as an ADR/spec note locally, do NOT fold it into production
   code, open no external issue, and return to the feature branch. `/feature` has
   not passed its gates yet, so no implementation lands here.

5. **Spec (inline):** synthesize (no re-interview) `docs/specs/<slug>.md` —
   Problem, Solution, User Stories, Implementation Decisions (incl. the test
   seams), Testing Decisions, Out of Scope, and a **`**Base:** <feature-base>`**
   line (the fork-point sha from step 1). **HUMAN GATE ↯ — spec approval.**

6. **Tickets (inline):** break the spec into tracer-bullet vertical slices at
   `tickets/<feature-slug>/<NN>-<slug>.md` (one dir per feature — ids never
   collide across features), in dependency order (blockers first), each with
   `**What to build:**`, `**Blocked by:**` (ids or None), `**Status:**
   ready-for-agent`, and acceptance checkboxes. **HUMAN GATE ↯ — ticket approval.**

Commit the artifacts and hand off to `/work`.
