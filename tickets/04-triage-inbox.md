# 04 — /triage: inbox namespace + triage states

**What to build:** rewrite `/triage` to work the `tickets/inbox/` queue with the
triage state vocabulary, separate from feature execution.

**Blocked by:** 01 — uses the helper's inbox namespace + states.

**Status:** ready-for-agent

- [ ] Intake items are `tickets/inbox/<id>.md`; states `needs-triage`,
      `needs-info`, `ready-for-human`, `wontfix`, `ready-for-feature`.
- [ ] Inline the triage state machine (Matt's `triage` is user-only): categorize,
      redundancy/prior-rejection check, verify the claim, decide a state.
- [ ] "Needs attention" lists inbox items not in a terminal state; these NEVER
      count toward a feature's completion (that's `/work`/`/ship` on
      `features/<slug>/`).
- [ ] Adopting an item → `ready-for-feature`, hand off to `/feature` (which
      creates the branch/worktree + feature ticket dir).
- [ ] Fleshing out → invoke model-invocable `grilling` + `domain-modeling`.
- [ ] Update frontmatter/description.
