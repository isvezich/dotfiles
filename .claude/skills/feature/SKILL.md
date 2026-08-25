---
name: feature
disable-model-invocation: true
description: Start an approved feature — create its branch+worktree first, design it (grilling/domain-modeling), then write a local spec and tickets committed on the branch with commit-pinned approval. Writes LOCAL files only. Two human gates. Invoke explicitly as /feature.
when_to_use: When starting a new, approved piece of work and you need a design, spec, and ticket breakdown before implementation. The user runs /feature. Follows /triage adopting an inbox item, or is itself the intake for solo idea-driven work.
version: 2.0.0
languages: all
---

# /feature — design and break down work (v2)

Router. Shared rules + the v2 state model are in
`~/.claude/skills/dev-workflow/workflow.md` — read it first this session.

**Invocability:** a router can only invoke *model-invocable* skills. Invoke
`grilling`, `domain-modeling`, `research`, `prototype`, `codebase-design`. Matt's
`grill-with-docs`/`to-spec`/`to-tickets` are user-only — their (interview-free)
logic is inlined below.

`W=~/.claude/skills/dev-workflow/scripts/workflow-state.sh`

## Steps

1. **Guard, then branch + worktree FIRST.** `bash $W init`, then
   **`bash $W set-status designing` BEFORE recording anything** — it only
   succeeds from `idle`/`triaging`, so it aborts here (no ledger corruption) if a
   previous feature is still `working`/`ready-to-work`/`parked`/`pr-open` (finish
   or park it first). Only on success: invoke `superpowers:using-git-worktrees`,
   then **explicitly create/verify the named feature branch** — that skill may
   reuse an existing/detached worktree or fall back to the current checkout, so
   confirm you are on a fresh `feature/<slug>` branch (create it if not) rather
   than trusting the outcome. `cd` into the worktree; `bash $W set feature <slug>`,
   `bash $W set branch feature/<slug>`. (Ledger is in the git-common-dir, shared
   with the primary checkout.)

2. **Classify (inline — do not hand control to brainstorming's full flow).**
   `superpowers:brainstorming` is not a classification primitive: for
   architectural work it writes/commits its own spec and mandates
   `writing-plans`; for bounded work it jumps to implementation — either bypasses
   steps 3–6. So classify here yourself (spike / bounded / architectural), state
   it, and hold the "no implementation before approval" gate. Consult
   brainstorming's rubric if useful, but keep control in this router.

3. **Grill + capture docs** — invoke `mattpocock-skills:grilling` and
   `mattpocock-skills:domain-modeling` (model-invocable). Land domain terms in
   `CONTEXT.md`, hard-to-reverse decisions as ADRs in `docs/decisions/`.

4. **De-risk as needed** — `research` (background primary-source facts),
   `prototype` (throwaway spike), `codebase-design` (seam/depth vocabulary).

5. **Spec (inlined, committed)** — synthesize (no re-interview) `docs/specs/<slug>.md`:
   Problem, Solution, User Stories, Implementation Decisions (incl. test seams —
   prefer existing, highest seam), Testing Decisions, Out of Scope. **Commit it.**
   **HUMAN GATE ↯ — spec approval.** On approval: `bash $W approve-spec $(git rev-parse HEAD)`.

6. **Tickets (inlined, committed)** — break the spec into tracer-bullet vertical
   slices at `tickets/features/<slug>/<NN>-<slug>.md`, each with `**What to
   build:**`, `**Blocked by:**` (ids or None), `**Status:** ready-for-agent`, and
   acceptance checkboxes; size each to one fresh context window. **Commit them.**
   Then `bash $W graph-validate <slug>` (fix any cycle/dup/no-frontier it reports).
   **HUMAN GATE ↯ — ticket approval.** On approval:
   `bash $W approve-tickets $(git rev-parse HEAD) tickets/features/<slug>/*.md`
   → status becomes `ready-to-work`.

Hand off to `/work` once `ready-to-work`.
