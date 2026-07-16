# End-to-end scenario testing — when and how to use it here

A decision + discipline guide for Claude. The mechanics (card format, browser/tmux
driving recipes, hard-won principles) live in the **`e2e-scenario-testing` skill** —
read the skill before writing your first card. This doc says *when* to reach for it,
*which* tool, and *where it fits* our workflow.

## What you have

- **`e2e-scenario-testing`** (skill) — verifies a *running* app through its real
  interface (web / CLI / TUI) using **scenario cards**: short markdown tests you
  author and then execute, each with a falsification condition. One card = one
  behavior = one `.md` file.
- **`/story-loop`** (command) — the bulk driver. It inventories *every* externally
  observable capability in a repo, writes one card per capability, records a status
  ledger, then loops test → fix → re-test until each capability is verified. Uses
  the skill for card format and running.

## Which one, when

| Situation | Use |
|---|---|
| A change touched one user-facing surface and you want live proof | the **skill** — write and run one card (a few at most) |
| "Test it end to end" / "prove the UI actually works" / "write a scenario" | the **skill** |
| "Drive this repo to a known-good state" / harden a whole project / build a behavioral regression suite from scratch | **`/story-loop`** |

`/story-loop` is a campaign, not a quick check — reach for it deliberately, not for a
single-feature verification.

## Where it fits our workflow

- It sits **above** unit tests and TDD, not instead of them. A green unit test proves
  the wiring in isolation; a scenario card proves it *as assembled and rendered*. They
  catch different bugs — **write the card even when the unit tests pass.**
- It is the concrete form of `verification-before-completion` for any change with a
  user-facing surface: don't claim "it works" until a card has driven the real
  interface and you've observed the result.

## Non-negotiable discipline (defer to the skill for the how)

- **Build fresh** from the code under test — the #1 mistake is testing a stale binary.
- **Isolate** — give the test instance its own `$HOME` / state dir / port so it can't
  collide with or pollute a real instance; symlink read-only creds, keep mutable state
  separate.
- **Falsification, always** — every assertion states what failure looks like. A step
  that can't fail proves nothing. Silence is not success.
- **On-disk truth over pixels** — the UI can lie or lag; cross-check the rendered claim
  against the log / state file / database when an assertion is ambiguous.
- **Idempotent cleanup, scoped to what you created** — leave pre-existing instances
  running and untouched.
- **Honest verdict** — report each assertion pass/fail with the concrete observation
  (the rendered text, the on-disk value), never "looks good."

## When NOT to use

- Logic with no UI surface → unit-test it.
- API-only checks or pure code review.
- A path that production gating makes unreachable — confirm the gate in the source and
  verify the underlying behavior with a unit test instead.

## Cards are durable

Commit cards (under `test/scenarios/` when driving a whole repo via `/story-loop`) —
they outlive the loop as the project's behavioral regression suite.
